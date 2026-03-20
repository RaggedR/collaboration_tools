# Component: Models

> Data classes representing the five core domain objects — the types everything else passes around.

## Responsibility

**Owns:** The shape of data as it moves between layers (database ↔ queries ↔ handlers ↔ JSON responses). Each model is a plain Dart class with typed fields and serialisation.

**Does NOT own:** Persistence, validation, or business logic. Models are inert data containers — they don't know how to save themselves or check whether they're valid.

## Public Interface

### Entity (`lib/models/entity.dart`)

```dart
class Entity {
  final String id;          // UUID, assigned on creation
  final String type;        // References entity_types.key
  final String name;
  final Map<String, dynamic> metadata;  // Validated against metadata_schema
  final String? createdBy;  // UUID of creating user
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

- `type` is immutable after creation — updates can change `name` and `metadata` but not `type`.
- `metadata` is a free-form JSONB map; validation happens in `MetadataValidator`, not here.
- `createdBy` is nullable to support seed data or system-created entities.

### Relationship (`lib/models/relationship.dart`)

```dart
class Relationship {
  final String id;               // UUID
  final String relTypeKey;       // References rel_types.key
  final String sourceEntityId;   // UUID → entities.id
  final String targetEntityId;   // UUID → entities.id
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
}
```

When returned from `EntityQueries.getWithRelationships()`, relationships are enriched with resolved context:

```dart
// Resolved relationship (as returned in entity detail views)
class ResolvedRelationship {
  final String id;
  final String relTypeKey;
  final String direction;    // 'forward' | 'reverse'
  final String label;        // forward_label or reverse_label, based on direction
  final RelatedEntity relatedEntity;  // { id, type, name }
  final Map<String, dynamic> metadata;
}
```

- `direction` and `label` depend on which entity you're viewing from: if you're the source, direction is `'forward'` and label is `forward_label`; if you're the target, direction is `'reverse'` and label is `reverse_label`.
- For symmetric relationships (e.g. `collaborates`), both directions use the same label (`'works with'`).

### EntityType (`lib/models/entity_type.dart`)

```dart
class EntityType {
  final String key;           // Primary key, e.g. 'task'
  final String label;         // Display name, e.g. 'Task'
  final String plural;        // Plural display, e.g. 'Tasks'
  final String? icon;         // Material icon name
  final String color;         // Hex color, e.g. '#10b981'
  final bool hidden;          // Hidden from default UI listings
  final Map<String, dynamic>? metadataSchema;  // JSON Schema for metadata validation
  final int sortOrder;        // Display ordering
}
```

- `metadataSchema` is optional — when null, any metadata is accepted for entities of this type.
- `key` must be unique across all entity types; enforced by `SchemaLoader.validate()`.

### RelType (`lib/models/rel_type.dart`)

```dart
class RelType {
  final String key;              // Primary key, e.g. 'assigned_to'
  final String forwardLabel;     // e.g. 'assigned to'
  final String reverseLabel;     // e.g. 'responsible for'
  final List<String> sourceTypes;  // Valid source entity type keys
  final List<String> targetTypes;  // Valid target entity type keys
  final bool symmetric;         // If true, direction doesn't matter
  final Map<String, dynamic>? metadataSchema;
}
```

- `sourceTypes` and `targetTypes` must reference valid entity type keys; enforced at validation time.
- Self-referential relationships are valid (e.g. `depends_on`: task → task).

### PermissionRule (`lib/models/permission_rule.dart`)

```dart
class PermissionRule {
  final String ruleType;          // 'admin_only_entity_type' | 'edit_granting_rel_type' | ...
  final String? entityTypeKey;    // Set when rule applies to an entity type
  final String? relTypeKey;       // Set when rule applies to a rel type
}
```

- Which fields are populated depends on `ruleType`:
  - `admin_only_entity_type` → `entityTypeKey` is set
  - `edit_granting_rel_type` → `relTypeKey` is set
  - `requires_approval_rel_type` → `relTypeKey` is set
  - `admin_only_rel_type` → `relTypeKey` is set
- The database table also has `id` (UUID) and `config` (JSONB) fields — see [BACKEND.md](../BACKEND.md#config-tables-populated-from-schemaconfig) for the full SQL schema.

## Dependencies

None. Models are leaf nodes in the dependency graph.

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `SchemaLoader` | Produces `EntityType`, `RelType`, `PermissionRule` from parsed config |
| `SchemaCache` | Stores and serves `EntityType`, `RelType`, `PermissionRule` |
| `MetadataValidator` | Reads `metadataSchema` from `EntityType` |
| `EntityQueries` | Returns `Entity` instances; uses `EntityType` for type validation |
| `RelationshipQueries` | Returns `Relationship` instances; uses `RelType` for constraint checking |
| `SchemaQueries` | Returns `EntityType`, `RelType`, `PermissionRule` from database |
| `PermissionResolver` | Takes `List<PermissionRule>` in constructor |
| All API handlers | Serialize models to JSON responses |

## Data Flow

Models flow in two directions:

1. **Config → Models:** `SchemaLoader` parses `schema.config` JSON into `EntityType`, `RelType`, and `PermissionRule` instances.
2. **Database → Models:** Query classes (`EntityQueries`, `RelationshipQueries`, `SchemaQueries`) hydrate database rows into model instances.

Models are serialised to JSON in API handlers for HTTP responses.

## Error Handling

Models themselves produce no errors. They're constructed by query classes and the schema loader, which handle validation before construction.

## Key Design Decisions

1. **Models are not ORM objects** — they don't extend a base class or know about the database. This keeps them testable and portable.
2. **ResolvedRelationship is separate from Relationship** — the raw database row (`Relationship`) doesn't have `direction` or `label`; those are computed at query time based on which entity is being viewed.
3. **PermissionRule uses nullable fields** — rather than a sealed class hierarchy, the rule type is a string and the relevant key field is set based on type. This mirrors the JSON structure in `schema.config`.

## Test Coverage

Models are not tested directly (they're plain data classes). They're exercised by every test file:

- `test/unit/permission_resolution_test.dart` — constructs `PermissionRule` instances
- `test/unit/schema_validation_test.dart` — validates config that produces model instances
- `test/integration/entity_lifecycle_test.dart` — creates and inspects `Entity` instances
- `test/integration/relationship_lifecycle_test.dart` — creates and inspects `Relationship` and `ResolvedRelationship`
- `test/integration/schema_sync_test.dart` — inspects `EntityType` and `RelType` properties from the database
