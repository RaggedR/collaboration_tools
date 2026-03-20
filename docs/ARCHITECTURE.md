# Architecture Overview

> The Outlier backend is a generic graph engine. It has no knowledge of what entity types, relationship types, or permission rules exist — everything is driven by `schema.config`.

## Component Map

```
bin/
  server.dart ─────────── Entry point: startup orchestration
                           │
                           ├── reads schema.config
                           ├── connects to PostgreSQL
                           └── wires all components together

lib/
  config/
    schema_loader.dart ─── Validates config, syncs to database
    schema_cache.dart ──── In-memory cache of current schema
    metadata_validator.dart ─ Validates entity metadata against JSON Schema

  db/
    database.dart ──────── PostgreSQL connection + migrations
    entity_queries.dart ── Entity CRUD (create, get, update, delete, list)
    relationship_queries.dart ─ Relationship CRUD with type constraint enforcement
    schema_queries.dart ── Read-only access to config tables

  auth/
    auth.dart ──────────── JWT authentication (register, login, logout, me)
    permissions.dart ───── Config-driven permission resolver

  api/
    router.dart ────────── Route definitions
    entity_handler.dart ── /api/entities endpoints
    relationship_handler.dart ─ /api/relationships endpoints
    schema_handler.dart ── /api/schema, /api/entity-types, /api/rel-types
    graph_handler.dart ─── /api/graph endpoint
    plugin_handler.dart ── /api/plugins/install, /api/plugins/export

  models/
    entity.dart
    relationship.dart
    entity_type.dart
    rel_type.dart
    permission_rule.dart
```

## Dependency Graph

```
                    ┌─────────┐
                    │ Models  │  ← zero dependencies, everything depends on these
                    └────┬────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
        ┌──────────┐ ┌───────┐ ┌──────┐
        │  Config  │ │  DB   │ │ Auth │
        │ (loader, │ │       │ │      │
        │  cache,  │ │       │ │      │
        │ m.valid) │ │       │ │      │
        └────┬─────┘ └───┬───┘ └──┬───┘
             │            │        │
             │     ┌──────┘        │
             ▼     ▼               ▼
        ┌──────────────────────────────┐
        │           API               │
        │ (router + 5 handlers)       │
        └──────────────┬───────────────┘
                       │
                       ▼
                 ┌───────────┐
                 │  Server   │
                 │ (bin/)    │
                 └───────────┘
```

### Detailed Dependencies

| Component | Depends On |
|-----------|-----------|
| **Models** | (nothing) |
| **SchemaLoader** | Models, Database |
| **SchemaCache** | Models |
| **MetadataValidator** | (standalone — takes schema + data, returns result) |
| **Database** | (standalone — PostgreSQL connection) |
| **EntityQueries** | Database, SchemaCache, MetadataValidator |
| **RelationshipQueries** | Database, SchemaCache |
| **SchemaQueries** | Database |
| **Auth** | (standalone — JWT library) |
| **PermissionResolver** | Models (PermissionRule) |
| **All Handlers** | Query classes, PermissionResolver, SchemaCache |
| **Router** | Handlers |
| **Server** | Everything (wires it all together) |

Dependencies form a strict DAG — no circular dependencies.

## Data Flows

### 1. Startup

```
schema.config (file) → SchemaLoader.validate() → SchemaLoader.syncToDatabase()
                                                          ↓
                                              ┌─ entity_types table
                                              ├─ rel_types table
                                              └─ permission_rules table
                                                          ↓
                                              SchemaCache.refresh()
                                                          ↓
                                              In-memory cache (ready for queries)
```

### 2. Frontend Initialisation

```
Flutter app starts
    → GET /api/schema (no auth required)
    ← { app, entity_types, rel_types, permission_rules }
    → Build UI from response:
        - Navigation items from entity_types (filtered by hidden flag)
        - Kanban columns from task metadata_schema.status.enum
        - Relationship pickers from rel_types (source/target constraints)
        - Permission-aware UI from permission_rules
```

### 3. Entity Creation

```
POST /api/entities { type: "task", name: "...", metadata: {...} }
    → Auth middleware: extract user from JWT
    → EntityHandler:
        → PermissionResolver.canCreate(entityType, isAdmin)
            → Checks admin_only_entity_type rules
        → EntityQueries.create(type, name, metadata, createdBy)
            → Validate type exists (from cache)
            → MetadataValidator.validate(type.metadataSchema, metadata)
            → INSERT INTO entities
            → Check auto_relationships → create if matched
        ← 201 { entity: {...} }
```

### 4. Graph Query

```
GET /api/graph?root_id=X&depth=2
    → GraphHandler:
        → If root_id: BFS from root entity, expanding relationships up to depth
        → For each entity: attach color + icon from entity type (via cache)
        → For each relationship: attach label from rel type (via cache)
        ← 200 { nodes: [...], edges: [...] }
```

### 5. Plugin Install (Schema Hot-Swap)

```
POST /api/plugins/install { ...new schema.config... }
    → Auth middleware: admin check → 403 if not admin
    → PluginHandler:
        → SchemaLoader.validate(newConfig) → 400 if invalid
        → SchemaLoader.syncToDatabase(newConfig, db)
            → Transaction: upsert types, replace rules
        → SchemaCache.refresh(newConfig)
        ← 200 { new schema }
    → Existing entities are NOT deleted (may become orphaned)
```

## Schema as the Source of Truth

The central design principle: **`schema.config` drives everything**.

```
schema.config
    ├── defines what entity types exist
    ├── defines what relationship types exist (with type constraints)
    ├── defines what permission rules apply
    ├── defines auto-relationships (e.g., sprint → owned_by → current_user)
    └── defines metadata schemas for validation
```

The backend code is generic. Changing the schema from an accountability tracker to a grant-writing tool requires zero code changes — only a different `schema.config`. This is tested explicitly: the test suite includes an `alternativeValidSchema()` ("Grant Writer") that validates, syncs, and serves correctly alongside the real Outlier config.

## Test Architecture

```
test/
  unit/                          ← No database, no server
    schema_validation_test.dart     SchemaLoader.validate()
    permission_resolution_test.dart PermissionResolver
    metadata_validation_test.dart   MetadataValidator.validate()

  integration/                   ← Real database, no server
    schema_sync_test.dart           SchemaLoader.syncToDatabase() + SchemaQueries
    entity_lifecycle_test.dart      EntityQueries (full CRUD)
    relationship_lifecycle_test.dart RelationshipQueries (constraints, labels, symmetric)

  e2e/                           ← Real database + real server process
    schema_api_test.dart            GET /api/schema, /api/entity-types, /api/rel-types
    entity_api_test.dart            Full entity CRUD via HTTP
    relationship_api_test.dart      Full relationship CRUD via HTTP
    graph_api_test.dart             GET /api/graph
    plugin_api_test.dart            Plugin install/export

  helpers/
    fixtures.dart                   Schema fixtures + test credentials
    test_server.dart                Manages server subprocess for E2E
    test_client.dart                HTTP client wrapper with typed methods
```

**Test strategy by layer:**
- **Unit tests** verify pure logic (validation, permissions) — fast, no I/O
- **Integration tests** verify database interactions — need PostgreSQL, no HTTP
- **E2E tests** verify the full stack — spawn real server, make real HTTP calls

## Reading Paths

### Robin (backend developer)
All 7 docs, starting with Models → Config → Database → Auth → API → Server → this doc.

### Nick (frontend developer)
Three docs only:
1. **This doc** — understand the overall system and data flows
2. **[COMPONENT_API.md](./COMPONENT_API.md)** — endpoint details, handler logic, what each endpoint expects and returns
3. **[COMPONENT_AUTH.md](./COMPONENT_AUTH.md)** — how permissions work, what triggers 403s, how to handle auth tokens

For exact HTTP request/response shapes, see [API.md](../API.md).

## Component Documentation Index

| Doc | Covers | Link |
|-----|--------|------|
| Models | Entity, Relationship, EntityType, RelType, PermissionRule | [COMPONENT_MODELS.md](./COMPONENT_MODELS.md) |
| Config | SchemaLoader, SchemaCache, MetadataValidator | [COMPONENT_CONFIG.md](./COMPONENT_CONFIG.md) |
| Database | Database, EntityQueries, RelationshipQueries, SchemaQueries | [COMPONENT_DATABASE.md](./COMPONENT_DATABASE.md) |
| Auth | Auth, PermissionResolver | [COMPONENT_AUTH.md](./COMPONENT_AUTH.md) |
| API | Router, all 5 handlers | [COMPONENT_API.md](./COMPONENT_API.md) |
| Server | bin/server.dart entry point | [COMPONENT_SERVER.md](./COMPONENT_SERVER.md) |

For the existing design documents:
- **[BACKEND.md](../BACKEND.md)** — SQL schema, project structure, high-level design
- **[API.md](../API.md)** — HTTP contract (request/response shapes, status codes)
- **[SCHEMA.md](../SCHEMA.md)** — Domain model rationale and research
- **[schema.config](../schema.config)** — The master configuration file

Design decisions:
- **[PERMISSIONS.md](./PERMISSIONS.md)** — Auth, users table, admin assignment, package choices (postgres + shelf), melb-tech lineage
