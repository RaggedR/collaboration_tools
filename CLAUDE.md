# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A schema-driven collaboration tool with kanban boards, sprints, documents, and project hierarchy. The backend is a **generic property graph engine** — it has no hardcoded knowledge of entity types. The frontend is **purpose-built** with hand-crafted screens for each entity type. `schema.config` is the source of truth that drives both.

## Commands

### Backend (from repo root)
```bash
# Start PostgreSQL
docker-compose up -d

# Install deps + run server
dart pub get
DATABASE_URL=postgresql://outlier:outlier@localhost:5433/outlier dart run bin/server.dart

# Run all backend tests (needs PostgreSQL running)
DATABASE_URL=postgresql://outlier:outlier@localhost:5433/outlier dart test

# Run a single test file
dart test test/unit/schema_validation_test.dart

# Run only e2e tests (tagged)
dart test --tags e2e

# Analyze
dart analyze lib/
```

### Frontend (from `frontend/`)
```bash
flutter pub get
flutter run -d chrome                    # Run in browser
flutter test                             # All tests
flutter test test/unit/                  # Unit tests only
flutter test test/widget/               # Widget tests only
flutter test test/unit/state/task_board_test.dart  # Single test file
dart analyze lib/                        # Analyze frontend code
```

### Docker (full stack)
```bash
docker build -t collab-tools .           # Multi-stage: Flutter web + Dart backend
# Serves frontend on same port as API (Flutter web build copied to /app/web)
```

### Deploy (GCP Cloud Run)
```bash
# Requires GCP_PROJECT_ID env var (default: collab-tools-prod)
./scripts/deploy-cloudrun.sh
```

## Architecture

### Two-Codebase Split

```
/                     Dart backend (package: outlier)
├── lib/api/          Shelf HTTP handlers (entity, relationship, schema, upload, plugin)
├── lib/db/           PostgreSQL queries (entities, relationships, schema sync)
├── lib/config/       Schema loading, caching, metadata validation
├── lib/auth/         JWT auth + permission resolution
├── bin/server.dart   Entry point — loads schema, syncs DB, starts HTTP server
├── schema.config     THE source of truth for all entity types, relationships, permissions
│
frontend/             Flutter web app (package: collaboration_tools)
├── lib/navigation/   GoRouter config + AppShell (nav rail + sidebar + content)
├── lib/screens/      Per-entity-type screens (my_page, tasks, sprints, documents)
├── lib/state/        Riverpod providers (task_board, sprint_list, document_list, sidebar, entity_detail)
├── lib/api/          ApiClient + typed models (entity, relationship, schema, auth)
├── lib/widgets/      Shared widgets (kanban, sidebar tree, filter bar, entity card, badges)
```

### Schema-Driven Design

`schema.config` defines entity types (task, sprint, document, project, workspace, person), relationship types (assigned_to, contains_task, in_sprint, etc.), permission rules, and auto-relationships. The backend reads this file on startup, validates it, and syncs the definitions to PostgreSQL. The frontend fetches the schema via `GET /api/schema` and derives UI elements (form fields, filter dropdowns, kanban columns, colors) from it.

**Key consequence**: To add a new entity type or relationship, edit `schema.config` and restart the server. The backend handles it automatically. The frontend may need new screens/widgets for good UX.

### Backend Data Model

Three core tables: `entities` (id, type, name, body, metadata JSONB), `relationships` (source_entity_id, target_entity_id, rel_type_key), and config tables synced from schema.config. All entity-type-specific data lives in the `metadata` JSONB column — the backend validates it against the entity type's `metadata_schema`.

### Frontend State Management

Riverpod with `StateNotifierProvider`. Key providers:
- `authProvider` — login state, JWT token
- `schemaProvider` — loaded once after login, drives all schema-dependent UI
- `sidebarProvider` — workspace/project tree, selected project for scoping (non-autoDispose, persists across navigation)
- `taskBoardProvider` — kanban columns with optimistic drag-and-drop updates
- `sprintListProvider` — temporal grouping (current/upcoming/completed)
- `entityDetailProvider.family` — per-entity detail loading, keyed by entity ID

### Navigation

Desktop (>900px): 72px nav rail + 200px collapsible sidebar + content. Mobile (<900px): bottom nav bar + hamburger drawer. Four screens: My Page, Tasks, Sprints, Documents. `StatefulShellRoute.indexedStack` keeps each screen's state independent.

### API Contract

All entities: `GET/POST /api/entities`, `GET/PUT/DELETE /api/entities/:id`. Filtering: `?type=task&related_to=<id>&rel_type=contains_task&metadata={"status":"active"}`. Relationships: `GET/POST /api/relationships`, `DELETE /api/relationships/:id`. Auth: `POST /api/auth/register`, `POST /api/auth/login`.

### Relationship Directions Matter

Relationships have source and target. `contains_task`: source=project, target=task. `in_sprint`: source=task, target=sprint. `assigned_to`: source=task, target=person. `contains_doc`: source=task, target=document. Getting these backwards silently creates invalid data.

## Testing Patterns

### Backend E2E Tests
Use `TestServer` (starts a real HTTP server with in-memory PostgreSQL URL) and `TestClient` (typed HTTP wrapper). Tests create entities and relationships via API, then assert responses. Tagged with `@Tags(['e2e'])`.

### Frontend Tests
- **Unit tests**: Pure Dart — test state grouping (task board columns), model deserialization, permission logic
- **Widget tests**: Pump widgets with mock providers using `mocktail`; test rendering and interaction
- **Mock API**: `MockApiClient` from mocktail in `test/helpers/mock_api.dart`

## CI

GitHub Actions runs on every PR and push to main: `dart analyze lib/` + `dart test` against a PostgreSQL service container. Deploy job runs `scripts/deploy.sh` on push to main (if the file exists).

## Environment Variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `DATABASE_URL` | Backend | PostgreSQL connection string |
| `JWT_SECRET` | Backend | JWT signing key (auto-generated if absent) |
| `PORT` | Backend | HTTP port (default: 8080) |
| `API_BASE_URL` | Frontend build | Backend URL (empty string = same-origin in Docker) |

## Gotchas

- The backend package is named `outlier` (in pubspec.yaml) but the project directory is `collaboration_tools`. Imports use `package:outlier/...`.
- PostgreSQL runs on port **5433** locally (not 5432) per docker-compose.yml.
- `flutter build web --dart-define=API_BASE_URL=` (empty) is intentional for Docker — makes the frontend use same-origin requests.
- Frontend `ApiClient` constructs URLs as `$baseUrl$path` — if baseUrl is empty, paths like `/api/entities` work for same-origin.
- `sidebarProvider` is intentionally non-autoDispose so project selection persists across screen navigation.
