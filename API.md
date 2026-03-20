# API Contract

## Base URL

`/api`

All responses are JSON. All request bodies are JSON. Auth token passed via `Authorization: Bearer <token>` header.

---

## Schema Discovery

These endpoints tell the frontend what the CMS is configured for. The frontend calls these on startup and builds its UI from the responses.

### GET /api/schema

Returns the full schema in one call (entity types, rel types, permission rules, app config). This is what the frontend uses to configure itself.

```json
{
  "app": {
    "name": "Outlier",
    "description": "Accountability tracker with kanban and knowledge graph",
    "theme_color": "#2563eb",
    "logo_url": null
  },
  "entity_types": [
    {
      "key": "task",
      "label": "Task",
      "plural": "Tasks",
      "icon": "check_circle",
      "color": "#10b981",
      "hidden": false,
      "metadata_schema": { ... }
    }
  ],
  "rel_types": [
    {
      "key": "assigned_to",
      "forward_label": "assigned to",
      "reverse_label": "responsible for",
      "source_types": ["task"],
      "target_types": ["person"],
      "symmetric": false
    }
  ],
  "permission_rules": [
    { "rule_type": "admin_only_entity_type", "entity_type_key": "workspace" },
    { "rule_type": "edit_granting_rel_type", "rel_type_key": "assigned_to" }
  ]
}
```

### GET /api/entity-types

Returns just the entity types array. Subset of `/api/schema`.

### GET /api/rel-types

Returns just the relationship types array. Subset of `/api/schema`.

---

## Entities

### GET /api/entities

List entities with optional filters.

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `type` | string | Filter by entity type key (e.g. `?type=task`) |
| `search` | string | Search entity names |
| `metadata` | JSON string | Filter by metadata fields (e.g. `?metadata={"status":"in_progress"}`) |
| `page` | integer | Page number (default: 1) |
| `per_page` | integer | Results per page (default: 50) |

**Response:**
```json
{
  "entities": [
    {
      "id": "uuid",
      "type": "task",
      "name": "Implement login",
      "metadata": { "status": "in_progress", "priority": "high" },
      "created_by": "user-uuid",
      "created_at": "2026-03-20T10:00:00Z",
      "updated_at": "2026-03-20T10:00:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "per_page": 50
}
```

### GET /api/entities/:id

Get a single entity with its relationships.

**Response:**
```json
{
  "entity": {
    "id": "uuid",
    "type": "task",
    "name": "Implement login",
    "metadata": { "status": "in_progress" },
    "created_by": "user-uuid",
    "created_at": "2026-03-20T10:00:00Z",
    "updated_at": "2026-03-20T10:00:00Z"
  },
  "relationships": [
    {
      "id": "rel-uuid",
      "rel_type_key": "assigned_to",
      "direction": "forward",
      "label": "assigned to",
      "related_entity": {
        "id": "person-uuid",
        "type": "person",
        "name": "Robin"
      },
      "metadata": {}
    },
    {
      "id": "rel-uuid-2",
      "rel_type_key": "contains_task",
      "direction": "reverse",
      "label": "belongs to",
      "related_entity": {
        "id": "project-uuid",
        "type": "project",
        "name": "CMS-Abstract"
      },
      "metadata": {}
    }
  ]
}
```

### POST /api/entities

Create an entity. Metadata is validated against the entity type's `metadata_schema` from schema.config.

**Request:**
```json
{
  "type": "task",
  "name": "Implement login",
  "metadata": { "status": "backlog", "priority": "high" }
}
```

**Response:** `201` with the created entity (same shape as GET).

**Errors:**
- `400` — invalid type, missing name, metadata fails schema validation
- `403` — entity type is admin-only and user is not admin

### PUT /api/entities/:id

Update an entity.

**Request:**
```json
{
  "name": "Implement login page",
  "metadata": { "status": "in_progress", "priority": "high" }
}
```

**Errors:**
- `403` — user doesn't have edit permission (no edit-granting relationship)
- `400` — metadata fails schema validation

### DELETE /api/entities/:id

Delete an entity. Cascades to delete all its relationships.

**Errors:**
- `403` — user doesn't have permission

---

## Relationships

### GET /api/relationships

List relationships with optional filters.

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `entity_id` | uuid | Relationships involving this entity (as source or target) |
| `rel_type` | string | Filter by rel type key |
| `page` | integer | Page number |
| `per_page` | integer | Results per page |

### POST /api/relationships

Create a relationship. The backend validates that source and target entity types match the rel type's `source_types` and `target_types` constraints. For symmetric relationships, the backend handles auto-swap (source/target order doesn't matter).

**Request:**
```json
{
  "rel_type_key": "assigned_to",
  "source_entity_id": "task-uuid",
  "target_entity_id": "person-uuid",
  "metadata": {}
}
```

**Errors:**
- `400` — type constraint violation (e.g. trying to assign a workspace to a person)
- `403` — rel type is admin-only, or requires approval
- `404` — source or target entity doesn't exist

### DELETE /api/relationships/:id

Delete a relationship.

---

## Graph

### GET /api/graph

Returns all entities and relationships in a format suitable for graph visualisation (d3-force, etc.).

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `root_id` | uuid | Optional: start from this entity and traverse N hops |
| `depth` | integer | Traversal depth from root (default: 2) |
| `types` | string | Comma-separated entity type keys to include |

**Response:**
```json
{
  "nodes": [
    { "id": "uuid", "type": "person", "name": "Robin", "color": "#ec4899", "icon": "person" }
  ],
  "edges": [
    { "id": "rel-uuid", "source": "uuid-1", "target": "uuid-2", "rel_type": "assigned_to", "label": "assigned to" }
  ]
}
```

---

## Plugins

### POST /api/plugins/install (admin-only)

Upload a `schema.config` file. The backend validates it, replaces the current config, resyncs the database, and refreshes the cache.

**Request:** The JSON body is a complete `schema.config` object.

**Response:** `200` with the new schema.

**What this does NOT do:** Delete existing entities or relationships. It only changes the type definitions and rules. Entities of a removed type would become orphaned — the admin panel should warn about this.

### GET /api/plugins/export

Export the current `schema.config` as JSON. This allows backing up the current configuration or sharing it.

---

## Auth

Auth endpoints are standard and not driven by schema.config. These are the same regardless of use case.

### POST /api/auth/login

### POST /api/auth/register

### POST /api/auth/logout

### GET /api/auth/me

---

## Error Format

All errors follow this shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Metadata field 'status' must be one of: backlog, todo, in_progress, review, done, archived",
    "field": "metadata.status"
  }
}
```

## Pagination Format

All list endpoints support pagination:

```json
{
  "data": [ ... ],
  "total": 142,
  "page": 1,
  "per_page": 50
}
```
