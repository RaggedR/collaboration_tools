# Component: Auth (Authentication + Permissions)

> Authenticates users via JWT tokens and resolves config-driven permission rules.

## Responsibility

**Owns:**
- User registration, login, logout, and session validation
- JWT token issuance and verification
- Permission resolution: determining whether a user can create or edit a given entity, based entirely on rules from `schema.config`

**Does NOT own:**
- What the permission rules are (that's `schema.config` via `SchemaCache`)
- Looking up relationships between user and entity (that's `EntityQueries` / `RelationshipQueries` — the handler passes pre-fetched relationship data to the resolver)
- HTTP request parsing or response formatting (that's `api/`)

## Public Interface

### Auth (`lib/auth/auth.dart`)

Standard authentication — not driven by `schema.config`. Endpoints:
- `POST /api/auth/register` — create account, returns JWT
- `POST /api/auth/login` — authenticate, returns JWT
- `POST /api/auth/logout` — invalidate token
- `GET /api/auth/me` — return current user info

Auth token is passed via `Authorization: Bearer <token>` header on all subsequent requests.

### PermissionResolver (`lib/auth/permissions.dart`)

```dart
class PermissionResolver {
  /// Construct with the current permission rules (from SchemaCache).
  PermissionResolver({required List<PermissionRule> rules});

  /// Can this user create an entity of the given type?
  /// Checks admin_only_entity_type rules.
  /// - If the type is admin-only and user is not admin → false
  /// - If the type is not admin-only → true (for any user)
  /// - Admin can always create any type → true
  bool canCreate({required String entityType, required bool isAdmin});

  /// Can this user edit this entity?
  /// Checks edit_granting_rel_type rules against the user's relationships.
  /// - Admin can always edit → true
  /// - If user has any relationship whose rel_type_key matches an
  ///   edit_granting_rel_type rule → true
  /// - Otherwise → false
  bool canEdit({
    required String entityType,
    required bool isAdmin,
    required List<String> userRelationships,  // rel_type_keys of user's rels to this entity
  });
}
```

### Permission Resolution Logic

The resolver is completely generic — it reads rule types and matches them against inputs. No entity type names or relationship type names are hardcoded.

**`canCreate` flow:**
1. Find all rules where `ruleType == 'admin_only_entity_type'`
2. If any rule has `entityTypeKey == entityType` and `isAdmin == false` → deny
3. Otherwise → allow

**`canEdit` flow:**
1. If `isAdmin` → always allow
2. Find all rules where `ruleType == 'edit_granting_rel_type'`
3. If any rule's `relTypeKey` appears in `userRelationships` → allow
4. Otherwise → deny

Key subtlety: **edit-granting rules are not entity-type-specific**. The `assigned_to` rule grants edit permission on *any* entity the user has that relationship to, not just tasks. The constraint that `assigned_to` only connects tasks to people is enforced by the rel type definition, not by the permission system. (This is tested explicitly in `permission_resolution_test.dart`: "edit-granting check is not entity-type-specific".)

### With No Rules Configured

When `permission_rules` is empty in `schema.config`:
- **Creation:** Anyone can create any entity type (no admin-only restrictions)
- **Editing:** Only admins can edit (no edit-granting rules means non-admins have no path to edit access)

## Dependencies

| Dependency | What it provides |
|-----------|-----------------|
| `models/permission_rule.dart` | `PermissionRule` data class |
| `config/schema_cache.dart` | Source of current `PermissionRule` list (the resolver is constructed with rules from the cache) |

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `api/entity_handler.dart` | Calls `canCreate()` before creating entities; calls `canEdit()` before updating/deleting |
| `api/relationship_handler.dart` | May check `admin_only_rel_type` and `requires_approval_rel_type` rules |
| `api/plugin_handler.dart` | Checks admin status for plugin install (admin-only endpoint) |
| `bin/server.dart` | Middleware that extracts user from JWT and attaches to request context |

## Data Flow

### Entity Creation Permission Check

```
POST /api/entities { type: "workspace", ... }
    ↓ entity_handler
    ├── Extract user from JWT (is admin?)
    ├── PermissionResolver.canCreate(entityType: "workspace", isAdmin: false)
    │   ├── Check: is "workspace" in admin_only_entity_type rules? → YES
    │   └── User is not admin → DENY
    └── Return 403
```

### Entity Edit Permission Check

```
PUT /api/entities/:id { ... }
    ↓ entity_handler
    ├── Extract user from JWT (is admin?)
    ├── Look up user's relationships to this entity
    │   (e.g., user has assigned_to relationship to this task)
    ├── PermissionResolver.canEdit(
    │     entityType: "task",
    │     isAdmin: false,
    │     userRelationships: ["assigned_to"],
    │   )
    │   ├── User is not admin → check edit-granting rules
    │   ├── "assigned_to" is an edit_granting_rel_type → ALLOW
    │   └── Return true
    └── Proceed with update
```

## Error Handling

| Operation | Error Condition | HTTP Status |
|-----------|----------------|-------------|
| Register | Duplicate email | 400 |
| Login | Wrong credentials | 401 |
| Any authenticated endpoint | Missing/invalid token | 401 |
| Create entity | Admin-only type, user not admin | 403 |
| Edit entity | No edit-granting relationship | 403 |
| Install plugin | User not admin | 403 |

## Key Design Decisions

1. **PermissionResolver is constructed, not a singleton** — it takes `rules` in its constructor, making it trivially testable without mocking a cache or database. In production, it's constructed from the cache; in tests, from inline rule lists.

2. **`canEdit` takes pre-fetched relationships** — the resolver doesn't query the database itself. The handler looks up "what relationships does this user have to this entity?" and passes the rel type keys as a `List<String>`. This keeps the resolver pure and database-free.

3. **Permissions are deny-by-default for editing** — a non-admin user with no edit-granting relationships cannot edit anything. This is the safe default: adding an `edit_granting_rel_type` rule opens access, not the other way around.

4. **Permissions are allow-by-default for creation** — entity types are creatable by everyone unless explicitly restricted by `admin_only_entity_type`. This keeps the common case simple (most types should be user-creatable).

5. **No per-entity ACLs** — permissions are based on relationship types, not individual permission grants. "Can user X edit entity Y?" reduces to "does user X have any edit-granting relationship to entity Y?" This is simpler than a traditional ACL model and scales with the graph structure.

## Test Coverage

| Test File | What it covers |
|-----------|---------------|
| `test/unit/permission_resolution_test.dart` | `PermissionResolver`: canCreate (admin-only types, non-admin-only types, admin override), canEdit (with/without edit-granting relationships, admin override, unrelated relationships, entity-type independence), empty rules behaviour, edge cases |
| `test/e2e/entity_api_test.dart` | HTTP-level permission enforcement: 403 on admin-only creation, 403 on edit without permission |
| `test/e2e/plugin_api_test.dart` | 403 when non-admin tries to install a plugin |
