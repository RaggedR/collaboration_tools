# Component: API (Router + Handlers)

> HTTP layer that maps REST endpoints to backend operations. Nick's primary reference for frontend integration.

## Responsibility

**Owns:**
- Route definitions (URL → handler mapping)
- Request parsing (JSON body, query parameters, path parameters)
- Response formatting (JSON serialisation, status codes, error shapes)
- Calling the right permission checks before data operations
- Orchestrating query classes and permission resolver for each endpoint

**Does NOT own:**
- Business logic or data validation (delegated to query classes and validators)
- Permission rule definitions (reads from `PermissionResolver`)
- Database access (delegated to query classes)
- Authentication token handling (delegated to auth middleware)

## Public Interface

### Router (`lib/api/router.dart`)

Maps HTTP routes to handler methods. See [API.md](../API.md) for the full HTTP contract (request/response shapes, query parameters, status codes).

### Handlers

Each handler file owns one resource's endpoints:

| Handler | File | Endpoints |
|---------|------|-----------|
| **EntityHandler** | `lib/api/entity_handler.dart` | `GET /api/entities`, `GET /api/entities/:id`, `POST /api/entities`, `PUT /api/entities/:id`, `DELETE /api/entities/:id` |
| **RelationshipHandler** | `lib/api/relationship_handler.dart` | `GET /api/relationships`, `POST /api/relationships`, `DELETE /api/relationships/:id` |
| **SchemaHandler** | `lib/api/schema_handler.dart` | `GET /api/schema`, `GET /api/entity-types`, `GET /api/rel-types` |
| **GraphHandler** | `lib/api/graph_handler.dart` | `GET /api/graph` |
| **PluginHandler** | `lib/api/plugin_handler.dart` | `POST /api/plugins/install`, `GET /api/plugins/export` |

## Dependencies

| Dependency | What it provides |
|-----------|-----------------|
| `db/entity_queries.dart` | Entity CRUD operations |
| `db/relationship_queries.dart` | Relationship CRUD operations |
| `db/schema_queries.dart` | Schema config lookups (or cache) |
| `config/schema_loader.dart` | `validate()` + `syncToDatabase()` for plugin install |
| `config/schema_cache.dart` | Current schema for discovery endpoints and permission construction |
| `auth/auth.dart` | JWT middleware for request authentication |
| `auth/permissions.dart` | `PermissionResolver` for access control |

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `bin/server.dart` | Mounts the router on the HTTP server |
| **Flutter frontend** | Calls all endpoints; `GET /api/schema` on startup to configure UI |

## Handler Detail

### EntityHandler (`lib/api/entity_handler.dart`)

**POST /api/entities** — Create entity
```
Request → parse { type, name, metadata }
    → PermissionResolver.canCreate(entityType, isAdmin) → 403 if denied
    → EntityQueries.create(type, name, metadata, createdBy)
        → validates type exists (400 if not)
        → validates metadata against schema (400 if invalid)
        → triggers auto-relationships
    → 201 { entity: { id, type, name, metadata, created_at, updated_at } }
```

**GET /api/entities** — List entities
```
Request → parse query params { type?, search?, metadata?, page?, per_page? }
    → EntityQueries.list(type, search, metadata, page, perPage)
    → 200 { entities: [...], total, page, per_page }
```

**GET /api/entities/:id** — Get entity detail
```
Request → parse path param { id }
    → EntityQueries.getWithRelationships(id) → 404 if not found
    → 200 { entity: {...}, relationships: [{ id, rel_type_key, direction, label, related_entity, metadata }] }
```

**PUT /api/entities/:id** — Update entity
```
Request → parse { name?, metadata? }
    → Look up user's relationships to entity
    → PermissionResolver.canEdit(entityType, isAdmin, userRelationships) → 403 if denied
    → EntityQueries.update(id, name, metadata) → 400 if metadata invalid
    → 200 { entity: {...} }
```

**DELETE /api/entities/:id** — Delete entity
```
Request → parse path param { id }
    → Permission check → 403 if denied
    → EntityQueries.delete(id) → cascades to relationships
    → 200 or 204
```

### RelationshipHandler (`lib/api/relationship_handler.dart`)

**POST /api/relationships** — Create relationship
```
Request → parse { rel_type_key, source_entity_id, target_entity_id, metadata? }
    → RelationshipQueries.create(...)
        → validates rel type exists (400)
        → validates source entity exists (404)
        → validates target entity exists (404)
        → validates source type ∈ source_types (400)
        → validates target type ∈ target_types (400)
    → 200 or 201 { id, rel_type_key, ... }
```

**GET /api/relationships** — List relationships
```
Request → parse query params { entity_id?, rel_type?, page?, per_page? }
    → RelationshipQueries.list(...)
    → 200 [...]
```

**DELETE /api/relationships/:id** — Delete relationship
```
Request → parse path param { id }
    → RelationshipQueries.delete(id)
    → 200 or 204
```

### SchemaHandler (`lib/api/schema_handler.dart`)

**GET /api/schema** — Full schema discovery (accessible WITHOUT auth)
```
    → Read from SchemaCache (or SchemaQueries)
    → 200 { app, entity_types, rel_types, permission_rules }
```

The schema endpoint is unauthenticated because the frontend needs it before the user logs in (to render branding, login screen theming, etc.).

**GET /api/entity-types** — Entity types only
```
    → 200 [ { key, label, plural, icon, color, hidden, ... }, ... ]
```

**GET /api/rel-types** — Relationship types only
```
    → 200 [ { key, forward_label, reverse_label, source_types, target_types, symmetric, ... }, ... ]
```

### GraphHandler (`lib/api/graph_handler.dart`)

**GET /api/graph** — Graph visualisation data
```
Request → parse query params { root_id?, depth? (default 2), types? (comma-separated) }
    → If root_id: BFS traversal from root, limited to depth hops
    → If types: filter nodes by entity type
    → 200 {
        nodes: [{ id, type, name, color, icon }],
        edges: [{ id, source, target, rel_type, label }]
      }
```

Node `color` and `icon` come from the entity type definition in the schema — they match exactly.

### PluginHandler (`lib/api/plugin_handler.dart`)

**POST /api/plugins/install** — Replace schema config (admin-only)
```
Request → full schema.config JSON body
    → Permission check: admin only → 403 if not admin
    → SchemaLoader.validate(config) → 400 if invalid
    → SchemaLoader.syncToDatabase(config, db)
    → SchemaCache.refresh(config)
    → 200 { new schema }
```

Does NOT delete existing entities. Entities of a removed type become orphaned.

**GET /api/plugins/export** — Export current config
```
    → Read from SchemaCache (or reconstruct from database)
    → 200 { app, entity_types, rel_types, permission_rules, auto_relationships, seed_data }
```

Round-trip guarantee: `export → install` produces the same schema.

## Error Handling

All errors follow the standard shape from [API.md](../API.md#error-format):

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Metadata field 'status' must be one of: backlog, todo, in_progress, review, done, archived",
    "field": "metadata.status"
  }
}
```

| Status | Meaning | Common Triggers |
|--------|---------|----------------|
| 400 | Bad request | Unknown entity type, metadata validation failure, type constraint violation, invalid schema config |
| 401 | Unauthorized | Missing or invalid auth token |
| 403 | Forbidden | Admin-only entity type, no edit-granting relationship, non-admin plugin install |
| 404 | Not found | Entity or relationship ID doesn't exist |

## Key Design Decisions

1. **Schema endpoint is unauthenticated** — `GET /api/schema` works without a token. The frontend calls this before login to get app branding (name, theme color, logo). Tested explicitly in `schema_api_test.dart`.

2. **Handlers are thin orchestrators** — each handler parses the request, calls the permission resolver, calls the query class, and formats the response. No business logic lives in handlers.

3. **Graph endpoint supports rooted traversal** — `root_id` + `depth` enables "show me everything within N hops of this entity," which is the primary knowledge graph interaction pattern. Without `root_id`, it returns the full graph (useful for small datasets).

4. **Plugin install validates before syncing** — the handler calls `SchemaLoader.validate()` and returns 400 before attempting `syncToDatabase()`. This ensures invalid configs never touch the database.

5. **Existing entities survive plugin install** — installing a new schema changes type definitions but doesn't delete entities. Entities of removed types become orphaned. The admin panel should warn about this (frontend responsibility).

## Nick's Reading Path

Nick (Flutter frontend) needs these three docs:
1. **[ARCHITECTURE.md](./ARCHITECTURE.md)** — component map and data flow overview
2. **This doc (COMPONENT_API.md)** — endpoint details and handler behaviour
3. **[COMPONENT_AUTH.md](./COMPONENT_AUTH.md)** — how permission rules work, what triggers 403s

For exact HTTP request/response shapes and query parameters, see [API.md](../API.md).

## Test Coverage

| Test File | What it covers |
|-----------|---------------|
| `test/e2e/schema_api_test.dart` | `SchemaHandler`: GET /api/schema (response shape, entity types, rel types, permission rules, unauthenticated access), GET /api/entity-types, GET /api/rel-types |
| `test/e2e/entity_api_test.dart` | `EntityHandler`: POST (201, 400, 403), GET list (pagination, type filter, search, metadata filter), GET detail (with relationships, 404), PUT (200, 400, 403), DELETE (cascade), error response format |
| `test/e2e/relationship_api_test.dart` | `RelationshipHandler`: POST (valid, type constraint violations, non-existent entities), self-referential, symmetric, GET list, DELETE |
| `test/e2e/graph_api_test.dart` | `GraphHandler`: node/edge shape, color matching, rooted traversal with depth, type filtering, empty graph |
| `test/e2e/plugin_api_test.dart` | `PluginHandler`: export, install (admin-only, invalid schema rejection, entity survival, schema reflection), round-trip |
