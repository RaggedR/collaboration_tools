# Component: Database (Connection + Query Classes)

> PostgreSQL connection management and all data access for entities, relationships, and schema config tables.

## Responsibility

**Owns:**
- PostgreSQL connection lifecycle (connect, migrate, close)
- All SQL queries for the three core tables (`entities`, `relationships`) and three config tables (`entity_types`, `rel_types`, `permission_rules`)
- Type constraint enforcement on relationship creation (source/target types match rel type definition)
- Pagination, search, and metadata filtering for entity listings
- Cascading delete behaviour (entity deletion removes all its relationships)
- Directional label resolution (forward/reverse labels based on viewing entity)
- Auto-relationship creation triggered by entity creation

**Does NOT own:**
- Schema validation or config parsing (that's `config/schema_loader.dart`)
- Permission checks (that's `auth/permissions.dart`)
- HTTP request/response handling (that's `api/`)

## Public Interface

### Database (`lib/db/database.dart`)

```dart
class Database {
  /// Connect to PostgreSQL.
  static Future<Database> connect(String databaseUrl);

  /// Run migrations to create/update tables.
  Future<void> migrate();

  /// Execute raw SQL (used in tests for cleanup).
  Future<void> execute(String sql);

  /// Close the connection.
  Future<void> close();
}
```

The database creates these tables on `migrate()` — see [BACKEND.md](../BACKEND.md#database-schema) for full SQL.

### EntityQueries (`lib/db/entity_queries.dart`)

```dart
class EntityQueries {
  EntityQueries({required Database db, required SchemaCache cache});

  /// Create an entity. Validates metadata against the type's schema.
  /// Triggers auto-relationships if configured.
  /// Throws on unknown type or invalid metadata.
  Future<Entity> create({
    required String type,
    required String name,
    required Map<String, dynamic> metadata,
    required String createdBy,
  });

  /// Get entity by ID. Throws on not found.
  Future<Entity> get(String id);

  /// Get entity with all its relationships resolved (direction + labels).
  Future<EntityWithRelationships> getWithRelationships(String id);

  /// Update entity name and/or metadata. Type is immutable.
  /// Validates metadata if provided. Updates `updated_at` timestamp.
  Future<Entity> update(
    String id, {
    String? name,
    Map<String, dynamic>? metadata,
  });

  /// Delete entity. Cascades to all relationships (via ON DELETE CASCADE).
  Future<void> delete(String id);

  /// List entities with optional filters and pagination.
  Future<PaginatedEntities> list({
    String? type,           // Filter by entity type key
    String? search,         // Partial, case-insensitive name search
    Map<String, dynamic>? metadata,  // Filter by metadata fields (JSONB containment)
    int page = 1,
    int perPage = 50,
  });
}

class EntityWithRelationships {
  final Entity entity;
  final List<ResolvedRelationship> relationships;
}

class PaginatedEntities {
  final List<Entity> entities;
  final int total;
}
```

### RelationshipQueries (`lib/db/relationship_queries.dart`)

```dart
class RelationshipQueries {
  RelationshipQueries({required Database db, required SchemaCache cache});

  /// Create a relationship. Validates:
  /// - rel type key exists
  /// - source entity exists and its type is in rel type's source_types
  /// - target entity exists and its type is in rel type's target_types
  /// For symmetric relationships, source/target order doesn't matter.
  /// Throws on constraint violation or non-existent entities.
  Future<Relationship> create({
    required String relTypeKey,
    required String sourceEntityId,
    required String targetEntityId,
    required String createdBy,
    Map<String, dynamic> metadata = const {},
  });

  /// List relationships with optional filters.
  /// When entityId is provided, returns relationships where the entity
  /// is either source or target.
  Future<List<Relationship>> list({
    String? entityId,
    String? relType,
    int? page,
    int? perPage,
  });

  /// Delete a relationship. Does not delete the connected entities.
  Future<void> delete(String id);
}
```

### SchemaQueries (`lib/db/schema_queries.dart`)

```dart
class SchemaQueries {
  SchemaQueries({required Database db});

  Future<List<EntityType>> listEntityTypes();
  Future<EntityType> getEntityType(String key);

  Future<List<RelType>> listRelTypes();
  Future<RelType> getRelType(String key);

  Future<List<PermissionRule>> listPermissionRules();
}
```

## Dependencies

| Dependency | What it provides |
|-----------|-----------------|
| `db/database.dart` | PostgreSQL connection (used by all query classes) |
| `config/schema_cache.dart` | In-memory schema for type validation and label resolution |
| `config/metadata_validator.dart` | Called by `EntityQueries` to validate metadata on create/update |
| `models/*` | All model classes for return types |

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `bin/server.dart` | Creates `Database`, calls `migrate()`, passes to query constructors |
| `config/schema_loader.dart` | `syncToDatabase()` uses `Database` directly for upsert operations |
| `api/entity_handler.dart` | Uses `EntityQueries` for CRUD |
| `api/relationship_handler.dart` | Uses `RelationshipQueries` for CRUD |
| `api/schema_handler.dart` | Uses `SchemaQueries` (or cache) for schema discovery endpoints |
| `api/graph_handler.dart` | Uses `EntityQueries` and `RelationshipQueries` for graph traversal |
| `api/plugin_handler.dart` | Uses `SchemaLoader.syncToDatabase()` which writes to the database |

## Data Flow

### Entity CRUD

```
EntityQueries.create(type, name, metadata, createdBy)
    ├── Look up EntityType from cache → reject if unknown type
    ├── MetadataValidator.validate(type.metadataSchema, metadata) → reject if invalid
    ├── INSERT INTO entities → Entity
    └── Check auto_relationships in cache → create owned_by / etc. if configured
```

```
EntityQueries.getWithRelationships(id)
    ├── SELECT entity by id
    ├── SELECT relationships WHERE source_entity_id = id OR target_entity_id = id
    ├── For each relationship:
    │   ├── Determine direction (forward if entity is source, reverse if target)
    │   ├── Resolve label (forward_label or reverse_label from RelType)
    │   └── Fetch related entity (the other end)
    └── Return EntityWithRelationships
```

### Relationship Creation with Type Constraints

```
RelationshipQueries.create(relTypeKey, sourceEntityId, targetEntityId, ...)
    ├── Look up RelType from cache → reject if unknown key
    ├── Look up source entity → reject if not found (404)
    ├── Look up target entity → reject if not found (404)
    ├── Check source entity.type ∈ relType.sourceTypes → reject if wrong type (400)
    ├── Check target entity.type ∈ relType.targetTypes → reject if wrong type (400)
    └── INSERT INTO relationships → Relationship
```

### Symmetric Relationship Handling

Symmetric relationships (e.g. `collaborates`) are stored as a single row. When queried:
- From either entity's perspective, the relationship is visible
- Both sides see the same label (forward and reverse labels are identical)
- No duplicate row is created

### Cascading Deletes

```
EntityQueries.delete(id)
    └── DELETE FROM entities WHERE id = ?
        └── ON DELETE CASCADE removes all rows in relationships
            where source_entity_id = id OR target_entity_id = id
```

The other entity in each deleted relationship is NOT deleted.

## Error Handling

| Operation | Error Condition | Behaviour |
|-----------|----------------|-----------|
| `create` entity | Unknown type | Throws |
| `create` entity | Invalid metadata | Throws (after `MetadataValidator` check) |
| `create` entity | Missing required metadata fields | Throws |
| `get` entity | ID not found | Throws |
| `update` entity | Invalid metadata | Throws |
| `create` relationship | Unknown rel type key | Throws |
| `create` relationship | Source entity not found | Throws |
| `create` relationship | Target entity not found | Throws |
| `create` relationship | Source type not in `source_types` | Throws |
| `create` relationship | Target type not in `target_types` | Throws |

API handlers catch these exceptions and map them to HTTP status codes (400, 404).

## Key Design Decisions

1. **Query classes take `SchemaCache` in their constructor** — this avoids per-query database lookups for type information. The cache is populated once on startup and refreshed only on schema changes.

2. **Type constraint enforcement happens in the query layer, not the database** — PostgreSQL foreign keys ensure `type` references `entity_types.key`, but the source/target type constraints on relationships are enforced in Dart code using the cached schema. This keeps the constraint logic generic and config-driven.

3. **Label resolution happens at query time** — `ResolvedRelationship` (with `direction` and `label`) is computed when fetching, not stored. This means changing a rel type's labels in the config takes effect immediately without migrating relationship rows.

4. **Auto-relationships fire inside `EntityQueries.create()`** — not in a separate post-creation hook. This ensures the auto-relationship is created in the same logical operation.

5. **Pagination returns total count** — `PaginatedEntities` includes `total` so the frontend can render page controls without a separate count query.

## Test Coverage

| Test File | What it covers |
|-----------|---------------|
| `test/integration/entity_lifecycle_test.dart` | `EntityQueries`: create, get, getWithRelationships, update, delete, list (with type/search/metadata filters, pagination), auto-relationships |
| `test/integration/relationship_lifecycle_test.dart` | `RelationshipQueries`: type constraint enforcement, self-referential rels, directional labels, symmetric relationships, listing/filtering, deletion |
| `test/integration/schema_sync_test.dart` | `SchemaQueries`: listEntityTypes, listRelTypes, listPermissionRules, getEntityType, getRelType; also tests `Database.connect()`, `migrate()`, `execute()` |
