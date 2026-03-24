# Component: App Shell & Routing

## Overview

The app shell provides the navigation frame (side rail or bottom nav) and the routing system. go_router handles deep linking, path parameters, and auth guards. The layout adapts between desktop (side rail + content) and mobile (bottom nav + full-page screens).

---

## Route Table

| Route | Screen | Auth Required | Notes |
|-------|--------|---------------|-------|
| `/login` | Login | No | Redirects to My Page if already authenticated |
| `/register` | Register | No | Redirects to My Page if already authenticated |
| `/` | Redirect | — | Redirects to `/person/<personEntityId>` |
| `/person/:id` | My Page | Yes | `:id` is the person entity UUID |
| `/tasks` | Tasks | Yes | Global kanban board |
| `/tasks/:id` | Task Detail | Yes | Mobile: full page. Desktop: handled within Tasks screen |
| `/sprints` | Sprints | Yes | Sprint list |
| `/sprints/:id` | Sprint Detail | Yes | Mobile: full page. Desktop: handled within Sprints screen |
| `/documents` | Documents | Yes | Document list |
| `/documents/:id` | Document Detail | Yes | Mobile: full page. Desktop: handled within Documents screen |
| `/graph` | Knowledge Graph | Yes | Interactive visualisation |

### go_router Configuration

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = auth.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
                          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/person/${auth.personEntityId}';
      if (isAuthenticated && state.matchedLocation == '/') return '/person/${auth.personEntityId}';
      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Main app routes (inside shell)
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/person/:id',
            builder: (_, state) => MyPageScreen(personId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tasks',
            builder: (_, __) => const TasksScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => TaskDetailScreen(taskId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/sprints',
            builder: (_, __) => const SprintsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => SprintDetailScreen(sprintId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/documents',
            builder: (_, __) => const DocumentsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => DocumentDetailScreen(docId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/graph', builder: (_, __) => const GraphScreen()),
        ],
      ),
    ],
  );
});
```

---

## App Shell

The `AppShell` wraps all authenticated screens. It provides the navigation chrome.

### Desktop Layout (>900px)

```
┌──────┬──────────────────────────────────────────────┐
│      │                                              │
│  My  │                                              │
│ Page │              Screen Content                  │
│      │                                              │
│ Tasks│         (may include a right detail panel)   │
│      │                                              │
│Sprint│                                              │
│  s   │                                              │
│      │                                              │
│ Docs │                                              │
│      │                                              │
│Graph │                                              │
│      │                                              │
│      │                                              │
│──────│                                              │
│ User │                                              │
│ ⚙️   │                                              │
└──────┴──────────────────────────────────────────────┘
   72px              remaining width
```

- **Side NavigationRail** (72px wide, Material 3 style)
- Navigation items:
  - My Page (home icon) → `/person/<personEntityId>`
  - Tasks (check_circle icon) → `/tasks`
  - Sprints (timer icon) → `/sprints`
  - Documents (description icon) → `/documents`
  - Graph (hub icon) → `/graph`
- Bottom of rail: user avatar + settings gear
- Active item highlighted

### Mobile Layout (<900px)

```
┌──────────────────────────────────────────────────┐
│                                                  │
│                                                  │
│               Screen Content                     │
│                                                  │
│           (full width, single column)            │
│                                                  │
│                                                  │
├──────────────────────────────────────────────────┤
│  🏠      ✅      ⏱️      📄      🔗             │
│ My Page  Tasks  Sprints  Docs   Graph            │
└──────────────────────────────────────────────────┘
```

- **BottomNavigationBar** (Material 3 style)
- Same 5 items as the side rail
- Active item highlighted with filled icon

### Breakpoint

```dart
class AppShell extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(...),
          Expanded(child: child),
        ],
      );
    } else {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(...),
      );
    }
  }
}
```

---

## Responsive Split-Pane (List + Detail)

On desktop, the Tasks, Sprints, and Documents screens use a split-pane layout: list on the left, detail panel on the right.

```
Desktop:
┌────────────────────────┬────────────────────────┐
│                        │                        │
│    List / Board        │    Detail Panel        │
│                        │                        │
│    (scrollable)        │    (scrollable)        │
│                        │                        │
└────────────────────────┴────────────────────────┘
         ~60%                    ~40%

Mobile:
┌────────────────────────────────────────────────┐
│                                                │
│    List / Board (full width)                   │
│                                                │
│    Tap item → navigates to /tasks/:id          │
│                                                │
└────────────────────────────────────────────────┘
```

On desktop, tapping an item opens the detail panel (no navigation). On mobile, tapping navigates to a new route.

The detail panel routes (`/tasks/:id`, etc.) are primarily for mobile and deep linking. On desktop, the parent screen handles showing/hiding the panel itself.

---

## Navigation Highlights

The active nav item is determined by the current route:

| Route | Active Item |
|-------|-------------|
| `/person/*` | My Page |
| `/tasks*` | Tasks |
| `/sprints*` | Sprints |
| `/documents*` | Documents |
| `/graph` | Graph |

---

## Route Guards

Handled entirely in go_router's `redirect`:

1. **Unauthenticated → `/login`**: Any non-auth route when not authenticated
2. **Authenticated → My Page**: Login/register routes when already authenticated
3. **`/` → My Page**: Root route always redirects to current user's My Page

No 403 routes — permission failures show inline messages (e.g., "You don't have permission to edit this task"), not separate error pages.

---

## Deep Linking

go_router supports deep linking out of the box. A URL like `https://app.example.com/person/abc-123` will:
1. Check auth → redirect to login if needed
2. After login → navigate to the original URL
3. Render My Page for person `abc-123`

This is important for sharing links to specific tasks, sprints, or person pages.

---

## User Menu

At the bottom of the side rail (desktop) or accessible via the user avatar:

- User name + email
- "My Page" shortcut
- "Logout" action
- Theme toggle (light/dark) — future feature

---

## Dependencies

- `go_router` package
- `authProvider` (see [COMPONENT_AUTH.md](./COMPONENT_AUTH.md))
- Material 3 `NavigationRail` and `NavigationBar` widgets
