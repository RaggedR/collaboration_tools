# Component: Authentication Flow

## Overview

Authentication is JWT-based. The backend handles user creation, password hashing (bcrypt), and token generation. The frontend manages token persistence, cold-start validation, and permission-aware UI rendering.

Key backend behaviour to understand:
- First registered user is auto-admin
- Registration auto-creates a `person` entity linked to the user via `person_entity_id`
- JWT expires after 7 days
- The `me` endpoint returns the full user object including `person_entity_id`

---

## Login Screen

**Route:** `/login`

### UI
- Email field (text input, email keyboard type)
- Password field (obscured)
- "Login" button
- "Don't have an account? Register" link → `/register`
- Error message area (below form)

### Flow

```
User submits email + password
  → POST /api/auth/login { email, password }
  → Success (200):
      { token: "jwt...", user: { id, email, name, is_admin, person_entity_id } }
      → Store token in flutter_secure_storage
      → Set AuthState with user data
      → Navigate to My Page (/person/<person_entity_id>)
  → Failure (401):
      { error: { code: "AUTH_ERROR", message: "Invalid credentials" } }
      → Show "Invalid email or password" below form
```

### Validation
- Email: non-empty, basic email format
- Password: non-empty
- Validate locally before making API call

---

## Register Screen

**Route:** `/register`

### UI
- Name field
- Email field
- Password field
- Confirm password field (client-side only — backend doesn't receive this)
- "Register" button
- "Already have an account? Login" link → `/login`

### Flow

```
User submits name + email + password
  → POST /api/auth/register { email, password, name }
  → Success (201):
      { token: "jwt...", user: { id, email, name, is_admin, person_entity_id } }
      → Store token
      → Set AuthState
      → Navigate to My Page
  → Failure (400):
      { error: { code: "REGISTRATION_ERROR", message: "..." } }
      → Show error (e.g. "Email already registered")
```

### Validation
- Name: non-empty
- Email: non-empty, basic email format
- Password: minimum 8 characters
- Confirm password: must match password

---

## Token Persistence

```dart
class TokenStore {
  final FlutterSecureStorage _storage;
  static const _key = 'auth_token';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
```

**Platform behaviour:**
- iOS: Keychain (encrypted, persists across app reinstalls by default)
- Android: EncryptedSharedPreferences (AES-256)
- Web: not targeted initially, but `flutter_secure_storage` falls back to localStorage

---

## Cold Start Flow

When the app launches, it doesn't know if the user is logged in:

```
App starts
  → Read token from secure storage
  → If no token: navigate to /login
  → If token exists:
      → GET /api/auth/me (with Bearer token)
      → If 200:
          { id, email, name, is_admin, person_entity_id }
          → Set AuthState
          → Fetch schema (GET /api/schema)
          → Navigate to My Page (/person/<person_entity_id>)
      → If 401 (token expired or invalid):
          → Clear stored token
          → Navigate to /login
      → If network error:
          → Show "Unable to connect" with retry button
```

### Sequence Diagram

```
┌──────┐     ┌──────────────┐     ┌──────────┐
│ App  │     │ TokenStore    │     │  Backend │
└──┬───┘     └──────┬───────┘     └────┬─────┘
   │   read token   │                  │
   │───────────────▶│                  │
   │   "jwt..."     │                  │
   │◀───────────────│                  │
   │         GET /api/auth/me          │
   │──────────────────────────────────▶│
   │         200 { user }              │
   │◀──────────────────────────────────│
   │   set AuthState                   │
   │         GET /api/schema           │
   │──────────────────────────────────▶│
   │         200 { schema }            │
   │◀──────────────────────────────────│
   │   set SchemaState                 │
   │   navigate to /person/:id         │
```

---

## Logout

```
User taps logout
  → Clear token from secure storage
  → Clear AuthState (set user to null)
  → Navigate to /login
  → Optionally: POST /api/auth/logout (backend currently doesn't invalidate JWTs server-side, but we send it for future compatibility)
```

---

## Permission Model in Frontend

The frontend checks permissions to show/hide UI elements. It never enforces permissions — that's the backend's job. The frontend just provides a good UX by not showing buttons the user can't use.

### Permission Rules (from schema)

```json
[
  { "rule_type": "admin_only_entity_type", "entity_type_key": "workspace" },
  { "rule_type": "admin_only_entity_type", "entity_type_key": "person" },
  { "rule_type": "edit_granting_rel_type", "rel_type_key": "assigned_to" },
  { "rule_type": "edit_granting_rel_type", "rel_type_key": "authored" }
]
```

### `canCreate(type)` — Can this user create entities of this type?

```
if user.isAdmin → true (admins can create anything)
if type is in admin_only_entity_type rules → false
else → true
```

| Entity Type | Admin | Non-Admin |
|-------------|-------|-----------|
| workspace | Create | Hidden |
| project | Create | Create |
| sprint | Create | Create |
| task | Create | Create |
| document | Create | Create |
| person | Create | Hidden |

### `canEdit(entity, relationships)` — Can this user edit this entity?

```
if user.isAdmin → true
if entity.createdBy == user.id → true (creator can always edit)
if user has an edit-granting relationship to this entity → true
else → false (show read-only view)
```

Edit-granting relationships from schema:
- `assigned_to`: if the current user's person entity is the target of an `assigned_to` relationship on this task, they can edit it
- `authored`: if the current user's person entity is the source of an `authored` relationship to this document, they can edit it

### `canEditPage(personId)` — Can this user modify content on this person's page?

```
if user.isAdmin → true
if personId == user.personEntityId → true (own page)
else → false (read-only view of others' pages)
```

This controls:
- Whether the kanban board on My Page allows drag-and-drop
- Whether "create task" / "create sprint" / "create document" buttons appear
- Whether edit/delete buttons appear on items in the page sections

---

## Auth State in Riverpod

```dart
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  String? get personEntityId => user?.personEntityId;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final TokenStore _tokenStore;

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.login(email: email, password: password);
      await _tokenStore.write(response.token);
      state = AuthState(user: response.user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> register(String name, String email, String password) async {
    // Same pattern as login
  }

  Future<void> checkSession() async {
    // Cold start: read token, call /me
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    state = const AuthState();
  }
}
```

---

## Admin Page Visiting

Admin users have a special capability: they can visit anyone's My Page and edit it as if it were their own.

This enables:
- Assigning tasks to other people
- Creating sprints on behalf of someone
- Managing documents for the team

Non-admin users can visit others' pages (for visibility into what colleagues are working on) but see a read-only view — no drag-and-drop, no create buttons, no edit buttons.

---

## Route Guards

Handled in go_router's `redirect` callback:

```dart
redirect: (context, state) {
  final auth = ref.read(authProvider);
  final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

  if (!auth.isAuthenticated && !isAuthRoute) {
    return '/login';  // Redirect unauthenticated users to login
  }
  if (auth.isAuthenticated && isAuthRoute) {
    return '/person/${auth.personEntityId}';  // Redirect logged-in users away from login
  }
  return null;  // No redirect needed
}
```
