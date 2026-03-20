# Component: Config (Schema Loader + Cache + Metadata Validator)

> Reads `schema.config`, validates it, caches the result in memory, and validates entity metadata at runtime.

## Responsibility

**Owns:**
- Parsing and validating `schema.config` JSON (structural correctness, cross-reference integrity)
- Syncing validated config into the database (upsert entity types, rel types, replace permission rules)
- In-memory cache of the current schema (entity types, rel types, permission rules)
- Validating entity metadata against per-type JSON schemas at create/update time

**Does NOT own:**
- Reading/writing individual entities or relationships (that's `db/`)
- Permission logic (that's `auth/permissions.dart`)
- HTTP request handling (that's `api/`)

## Public Interface

### SchemaLoader (`lib/config/schema_loader.dart`)

```dart
class SchemaLoader {
  /// Validates a parsed schema.config against structural rules.
  /// Returns all errors at once — does not stop at the first.
  static ValidationResult validate(Map<String, dynamic> config);

  /// Syncs a validated config into the database.
  /// Runs in a single transaction: upserts entity_types, upserts rel_types,
  /// replaces permission_rules, processes auto_relationships.
  /// Throws on invalid config (the database is not partially updated).
  static Future<void> syncToDatabase(Map<String, dynamic> config, Database db);
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;  // Human-readable error messages
}
```

**Validation rules** (tested in `schema_validation_test.dart`):
- `app` section must be present
- `entity_types` must be present and non-empty
- Each entity type must have a `key` field
- Entity type keys must be unique
- Rel type `source_types` and `target_types` must reference valid entity type keys
- Rel type keys must be unique
- Permission rules must reference valid entity type / rel type keys
- Auto-relationship rules must reference valid entity types and rel type keys
- `metadata_schema` is optional on entity types
- Self-referential rel types are valid (same type in source and target)

**Sync behaviour** (tested in `schema_sync_test.dart`):
- Idempotent — syncing the same config twice produces the same result
- Atomic — invalid config does not partially update the database
- Replaces permission rules entirely (not upsert)
- Upserts entity types and rel types (existing data updated, new data inserted)

### SchemaCache (`lib/config/schema_cache.dart`)

```dart
class SchemaCache {
  /// Populates the cache from a parsed config.
  /// Called on startup and on admin schema reload.
  void refresh(Map<String, dynamic> config);

  // Lookup methods used by query classes and permission resolver:
  // (exact API inferred from usage in EntityQueries, RelationshipQueries,
  //  and PermissionResolver — the cache provides type lookups)
}
```

- No TTL-based expiry — the cache is only refreshed on startup or admin reload.
- Consumed by `EntityQueries` and `RelationshipQueries` (both take `cache` in their constructor).

### MetadataValidator (`lib/config/metadata_validator.dart`)

```dart
class MetadataValidator {
  /// Validates metadata against a JSON Schema.
  /// Returns valid if schema is null (no validation applied).
  static ValidationResult validate(
    Map<String, dynamic>? schema,
    Map<String, dynamic> metadata,
  );
}
```

**Validation capabilities** (tested in `metadata_validation_test.dart`):
- Type checking: `string`, `number`, `array`, `object`
- Enum validation: rejects values not in the `enum` list
- Required fields: enforces `required` array in the schema
- Date format: accepts `YYYY-MM-DD`, rejects human-readable dates and full ISO datetimes
- Array items: validates that array items match the declared item type
- Null schema: when `metadata_schema` is null, any metadata is accepted

## Dependencies

| Dependency | What it provides |
|-----------|-----------------|
| `models/entity_type.dart` | `EntityType` data class |
| `models/rel_type.dart` | `RelType` data class |
| `models/permission_rule.dart` | `PermissionRule` data class |
| `db/database.dart` | Database connection for `syncToDatabase` |

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `bin/server.dart` | Calls `SchemaLoader.validate()`, `syncToDatabase()`, and `SchemaCache.refresh()` on startup |
| `EntityQueries` | Constructor takes `SchemaCache`; calls `MetadataValidator` on create/update |
| `RelationshipQueries` | Constructor takes `SchemaCache`; uses it for type constraint checking |
| `PermissionResolver` | Reads permission rules from the cache |
| `SchemaHandler` | Reads from the cache to serve `/api/schema`, `/api/entity-types`, `/api/rel-types` |
| `PluginHandler` | Calls `validate()` + `syncToDatabase()` + `cache.refresh()` on plugin install |

## Data Flow

### Startup / Plugin Install

```
schema.config (JSON file)
    ↓ parse
Map<String, dynamic>
    ↓ SchemaLoader.validate()
ValidationResult  ←── reject if invalid
    ↓ SchemaLoader.syncToDatabase()
Database tables (entity_types, rel_types, permission_rules)
    ↓ SchemaCache.refresh()
In-memory cache ──→ used by all runtime operations
```

### Entity Create / Update (metadata validation)

```
HTTP request body → { metadata: {...} }
    ↓
EntityQueries.create() / .update()
    ↓ look up entity type from cache
EntityType.metadataSchema
    ↓ MetadataValidator.validate(schema, metadata)
ValidationResult  ←── reject with 400 if invalid
    ↓ if valid
INSERT / UPDATE entities
```

## Error Handling

| Component | Error Type | Representation |
|-----------|-----------|---------------|
| `SchemaLoader.validate()` | Invalid config structure | `ValidationResult(isValid: false, errors: [...])` — collects all errors |
| `SchemaLoader.syncToDatabase()` | Invalid config | Throws (transaction rolled back, database unchanged) |
| `MetadataValidator.validate()` | Invalid metadata | `ValidationResult(isValid: false, errors: [...])` — field-level messages |

All errors are collected, not fail-fast. `SchemaLoader.validate()` reports errors for every broken cross-reference in a single pass (tested: "reports all errors at once, not just the first").

## Key Design Decisions

1. **Config file is source of truth, not the database** — the database reflects the config, not the other way around. This means schema changes require editing `schema.config` and restarting (or using the plugin install endpoint), not running migrations.

2. **Validation is a separate step from sync** — `validate()` is pure (no side effects), `syncToDatabase()` assumes valid input. The plugin handler calls validate first and returns 400 before attempting sync.

3. **MetadataValidator lives in config/, not in db/** — metadata validation is a schema concern (driven by `metadata_schema` from the config), not a database concern. It's called by `EntityQueries` but logically belongs with schema processing.

4. **No TTL on the cache** — since the config only changes on restart or admin action, the cache never goes stale during normal operation. This eliminates an entire class of cache invalidation bugs.

5. **`metadata_validator.dart` is not listed in BACKEND.md's project structure** — it was added after the initial design. The tests import it from `package:outlier/config/metadata_validator.dart`, confirming its location in `lib/config/`.

## Test Coverage

| Test File | What it covers |
|-----------|---------------|
| `test/unit/schema_validation_test.dart` | `SchemaLoader.validate()` — all validation rules, valid schemas, invalid schemas, cross-reference integrity |
| `test/unit/metadata_validation_test.dart` | `MetadataValidator.validate()` — enum, type, required, date format, array items, null schema |
| `test/integration/schema_sync_test.dart` | `SchemaLoader.syncToDatabase()` — initial sync, idempotency, updates, atomicity; also tests `SchemaCache.refresh()` indirectly |
| `test/e2e/plugin_api_test.dart` | Full round-trip: install plugin → validate → sync → cache refresh → verify via API |
