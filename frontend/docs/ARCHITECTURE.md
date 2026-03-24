# Frontend Architecture Overview

## Design Philosophy

**Hardcoded frontend, generic API.** The backend is a schema-driven graph engine — it knows nothing about tasks, sprints, or kanban boards. The frontend is the opposite: it knows exactly what Collaboration Tools looks like, with purpose-built screens for each entity type.

This means:
- The frontend calls `GET /api/schema` on startup to learn the current entity types, relationship types, and permission rules
- But the screens, layouts, and interactions are hand-crafted — not generated from schema
- The schema drives validation, metadata forms, and permission checks — not screen structure

Why not generic? A generic CMS UI is mediocre at everything. A kanban board, a sprint timeline, a knowledge graph — these each need bespoke UX. The schema still powers the data layer; the UI just isn't auto-generated from it.

---

## Screen Map

```
┌────────────────────────────────────────────────────────┐
│  App Shell (responsive: side rail / bottom nav)        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  [My Page]   [Tasks]   [Sprints]   [Documents]  [Graph]│
│                                                        │
│  /person/:id  /tasks    /sprints    /documents   /graph│
│                                                        │
│  + /login, /register (unauthenticated)                 │
└────────────────────────────────────────────────────────┘
```

- **My Page** (`/person/:id`) — the flagship. Shows tasks, sprints, and documents for one person. Your own page is home; you can visit others'.
- **Tasks** (`/tasks`) — global kanban board with filters (project, assignee, priority, sprint, labels)
- **Sprints** (`/sprints`) — sprint list grouped by status, with task breakdown per sprint
- **Documents** (`/documents`) — searchable document list with type/project/author filters
- **Graph** (`/graph`) — interactive knowledge graph (force-directed, filterable)

---

## Component Dependency Graph

```
                    ┌────────────────┐
                    │   API Client   │  ← pure Dart, no Flutter
                    │   + Models     │
                    └───────┬────────┘
                            │
                    ┌───────┴────────┐
                    │  State Layer   │  ← Riverpod providers/notifiers
                    │  (Riverpod)    │
                    └───────┬────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
      ┌───────┴──────┐ ┌───┴────┐ ┌──────┴───────┐
      │   Screens    │ │ Shared │ │  Navigation  │
      │              │ │Widgets │ │  + Routing   │
      └──────────────┘ └────────┘ └──────────────┘

Screens depend on: State + Shared Widgets
Shared Widgets depend on: Models (for type definitions)
Navigation depends on: State (for auth), Routing (go_router)
```

### Dependency Rules
- **API Client + Models** have zero Flutter dependencies — pure Dart `package:http`
- **State Layer** depends on API Client, uses `flutter_riverpod`
- **Shared Widgets** are stateless where possible, receive data via props
- **Screens** compose Shared Widgets and read from State providers
- **Navigation** reads AuthState to guard routes

---

## Data Flows

### 1. App Startup

```
App launches
  → Check secure storage for saved JWT token
  → If token exists:
      → GET /api/auth/me (validate token)
      → If valid: extract user + person_entity_id
      → If 401: clear token, show login
  → If no token: show login screen
  → After auth:
      → GET /api/schema (fetch entity types, rel types, permission rules)
      → Cache schema in SchemaState (Riverpod)
      → Navigate to My Page (/person/<current_user.person_entity_id>)
```

### 2. My Page Load

```
Navigate to /person/:personId
  → Parallel API calls (requires related_to enhancement):
      GET /api/entities?type=task&related_to=<personId>&rel_type=assigned_to
      GET /api/entities?type=sprint&related_to=<personId>&rel_type=owned_by
      GET /api/entities?type=document&related_to=<personId>&rel_type=authored
  → Render three sections:
      My Tasks: kanban board (reusable widget, filtered to this person)
      My Sprints: list of current + recent sprints
      My Documents: list of authored documents
```

### 3. Kanban Drag (Optimistic Update)

```
User drags task card from "todo" column to "in_progress"
  → Immediately move card in UI (optimistic)
  → PUT /api/entities/:id { metadata: { status: "in_progress", ...rest } }
  → If success: done (UI already correct)
  → If failure: rollback card to original column, show error snackbar
```

### 4. Relationship Creation

```
User clicks "Assign" on a task
  → Show person picker (search /api/entities?type=person)
  → User selects a person
  → POST /api/relationships {
      rel_type_key: "assigned_to",
      source_entity_id: <taskId>,
      target_entity_id: <personId>
    }
  → Refresh task detail to show new relationship
  → Invalidate affected states (My Page for that person, Tasks board)
```

---

## Permission-Aware UI Rules

The backend returns `permission_rules` in `GET /api/schema`. The frontend uses these to show/hide UI elements:

| Rule | Frontend Effect |
|------|----------------|
| `admin_only_entity_type: workspace` | Hide workspace create/edit for non-admins |
| `admin_only_entity_type: person` | Hide person create/edit for non-admins |
| `edit_granting_rel_type: assigned_to` | Non-admin can edit a task if assigned to it |
| `edit_granting_rel_type: authored` | Non-admin can edit a document if they authored it |

**My Page permission model:**
- Your own page: full edit (you're the person entity, so edit-granting rels apply)
- Others' pages: read-only (view their tasks, sprints, docs — but can't modify)
- Admin: can edit anyone's page

---

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State management | **Riverpod** | `family` modifier handles per-person My Page state; good testing story with `ProviderContainer` overrides |
| Entity detail display | **Right panel (desktop) / full page (mobile)** | Responsive split-pane keeps context visible on desktop |
| Drag-and-drop | **Evaluate `appflowy_board`** | Built for kanban use-case, saves significant work vs custom `Draggable` chains |
| Knowledge graph | **Native Flutter first** (`graphview` or `flutter_force_directed_graph`) | Avoids WebView overhead and platform-specific issues; d3.js WebView as fallback |
| Routing | **go_router** | Flutter standard, supports deep linking, path parameters, route guards |
| HTTP client | **`package:http`** | Lightweight, familiar; no need for dio's interceptor complexity |
| Token storage | **`flutter_secure_storage`** | Encrypted storage on iOS (Keychain) and Android (EncryptedSharedPreferences) |
| Project structure | **`frontend/` in same repo** | Shares `schema.config` reference; easy to split later if needed |

---

## Project Structure

```
frontend/
  pubspec.yaml
  lib/
    main.dart                    — entry point, ProviderScope
    app.dart                     — MaterialApp.router setup
    api/
      api_client.dart            — HTTP client with auth, error handling
      models/                    — Dart classes mirroring API JSON
        entity.dart
        relationship.dart
        schema.dart              — EntityType, RelType, PermissionRule
        graph.dart               — GraphNode, GraphEdge
        auth.dart                — User, AuthResponse
    state/
      schema_state.dart          — global schema provider
      auth_state.dart            — auth + current user provider
      my_page_state.dart         — per-person tasks/sprints/docs
      task_board_state.dart      — global kanban state
      sprint_list_state.dart     — sprint list + filters
      document_list_state.dart   — document list + filters
      graph_state.dart           — graph data provider
    screens/
      auth/
        login_screen.dart
        register_screen.dart
      my_page/
        my_page_screen.dart
        my_tasks_section.dart
        my_sprints_section.dart
        my_documents_section.dart
      tasks/
        tasks_screen.dart
        task_detail_panel.dart
        task_create_form.dart
      sprints/
        sprints_screen.dart
        sprint_detail_panel.dart
        sprint_create_form.dart
      documents/
        documents_screen.dart
        document_detail_panel.dart
        document_create_form.dart
      graph/
        graph_screen.dart
    widgets/
      kanban/
        kanban_board.dart
        kanban_column.dart
        kanban_card.dart
      shared/
        entity_card.dart
        priority_badge.dart
        status_badge.dart
        doc_type_badge.dart
        person_chip.dart
        metadata_form.dart
        relationship_list.dart
        search_bar.dart
        filter_bar.dart
        paginated_list.dart
        confirm_dialog.dart
        error_snackbar.dart
        loading_overlay.dart
    navigation/
      app_shell.dart
      router.dart
    theme/
      app_theme.dart
  test/                          — mirrors lib/ structure
  docs/                          — these 12 component specs
```

---

## Cross-References

| Doc | What It Covers |
|-----|---------------|
| [COMPONENT_API_CLIENT.md](./COMPONENT_API_CLIENT.md) | HTTP client, models, error handling |
| [COMPONENT_STATE.md](./COMPONENT_STATE.md) | Riverpod providers, state tree, optimistic updates |
| [COMPONENT_AUTH.md](./COMPONENT_AUTH.md) | Login/register, token persistence, permissions |
| [COMPONENT_MY_PAGE.md](./COMPONENT_MY_PAGE.md) | My Page screen, sections, visiting others |
| [COMPONENT_TASKS.md](./COMPONENT_TASKS.md) | Global kanban, task detail, create/edit |
| [COMPONENT_SPRINTS.md](./COMPONENT_SPRINTS.md) | Sprint list, detail, create |
| [COMPONENT_DOCUMENTS.md](./COMPONENT_DOCUMENTS.md) | Document list, detail, create |
| [COMPONENT_KANBAN.md](./COMPONENT_KANBAN.md) | Reusable kanban widget |
| [COMPONENT_GRAPH.md](./COMPONENT_GRAPH.md) | Knowledge graph visualisation |
| [COMPONENT_NAVIGATION.md](./COMPONENT_NAVIGATION.md) | Routing, app shell, responsive layout |
| [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md) | Badges, cards, forms, reusable pieces |
