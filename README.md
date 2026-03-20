# CMS-Abstract

A **generic, schema-driven CMS engine**. The backend is a graph engine in Dart, the frontend is a Flutter client. Neither side hardcodes any domain knowledge — everything is driven by a single `schema.config` file.

The first instance of this engine is **Outlier**, an accountability tracker with kanban boards and a knowledge graph.

## Current Status

| Component | Status | Owner |
|-----------|--------|-------|
| `schema.config` | Done | Robin |
| Backend (Dart) | Done | Robin |
| API contract | Done | Robin |
| **Frontend (Flutter)** | **TODO** | **Nick** |

Robin has completed the backend, the API contract, and the master schema config. **Nick, your job is to build the Flutter frontend.**

## How It Works

```
schema.config  (the single source of truth)
      │
      ├──► Backend reads it on startup, syncs into Postgres, caches in memory
      │
      └──► Frontend fetches it via GET /api/schema, builds all UI from it
```

The key idea: **to change what the app does, you edit `schema.config` — not code.** Add a new entity type, change colours, rename a relationship — the frontend adapts automatically.

## Repo Structure

```
schema.config            # THE master document — defines entity types, relationships, permissions
SCHEMA.md                # Schema design rationale and format explanation
BACKEND.md               # Backend architecture and project structure (Dart)
FRONTEND.md              # Frontend architecture — YOUR guide, Nick
API.md                   # Full API contract (REST endpoints, request/response shapes)
PRELIMINARY_IDEAS.md     # Early design thinking and brainstorming
docs/
  ARCHITECTURE.md        # Overall system architecture
  COMPONENT_API.md       # API layer — route handlers, request/response
  COMPONENT_AUTH.md      # Authentication and JWT
  COMPONENT_CONFIG.md    # Schema loading and config management
  COMPONENT_DATABASE.md  # Database schema and queries
  COMPONENT_MODELS.md    # Data models (Entity, Relationship, etc.)
  COMPONENT_SERVER.md    # Server setup and startup
  PERMISSIONS.md         # Permission system design
```

## For Nick: Getting Started

### 1. Read these files (in order)

1. **`docs/ARCHITECTURE.md`** — Big picture: how the system fits together
2. **`schema.config`** — The data model (entity types, relationships, permissions)
3. **`API.md`** — Your contract. Every endpoint you'll call is documented here
4. **`FRONTEND.md`** — The full frontend design spec, including screen architecture, state management, and your deliverables list
5. **`docs/PERMISSIONS.md`** — How permissions work (you'll need this for showing/hiding UI elements)

### 2. Your Deliverables

1. Generic entity list screen (search, filter, pagination)
2. Generic entity detail screen (metadata card + relationship list)
3. Generic entity create/edit form (built from JSON Schema)
4. Relationship create dialog
5. Kanban board view (for any entity type with a `status` enum)
6. Knowledge graph visualisation
7. Schema editor (admin only)
8. Navigation builder (reads entity types, builds sidebar/tabs)
9. App shell with branding from schema

### 3. Core Principle

The Flutter app is a **generic CMS client**. It must have zero hardcoded knowledge of entity types, relationship types, or permission rules. Everything is discovered at runtime from `GET /api/schema`.

- Navigation is built from `entity_types[]`
- Forms are built from `metadata_schema` (JSON Schema → widgets)
- Permissions are checked against `permission_rules[]`
- Kanban columns come from `status` enum values (any entity type that has one)

If the schema changes, the app adapts — no Flutter code changes needed.

### 4. Tech Decisions

- **Database:** PostgreSQL (with `shelf` for the Dart backend)
- **Auth:** JWT, separate `users` table, `is_admin` boolean
- **Backend framework:** Dart with shelf
- **Frontend:** Flutter

## API Quick Reference

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/schema` | Fetch full schema (startup bootstrap) |
| GET | `/api/entities?type=X` | List entities by type |
| GET | `/api/entities/:id` | Get entity + relationships |
| POST | `/api/entities` | Create entity (metadata validated against schema) |
| PUT | `/api/entities/:id` | Update entity |
| DELETE | `/api/entities/:id` | Delete entity (cascades relationships) |
| POST | `/api/relationships` | Create relationship (type-constrained) |
| DELETE | `/api/relationships/:id` | Delete relationship |
| GET | `/api/graph` | Graph data for visualisation (nodes + edges) |

See `API.md` for full details including request/response shapes and error formats.
