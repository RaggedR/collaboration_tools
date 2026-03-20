# Backend Design (Dart)

## Core Principle

The backend is a generic graph engine. It has **no knowledge** of what entity types, relationship types, or permission rules exist. Everything is driven by `schema.config`.

## Startup

1. Read and validate `schema.config` (JSON)
2. Ensure database tables exist (`entities`, `relationships`, `entity_types`, `rel_types`, `permission_rules`)
3. Sync `schema.config` into the database tables — upsert entity types, rel types, permission rules
4. Cache the schema in memory
5. Start serving the API

Changing the schema = edit `schema.config` → restart the server (or hit an admin reload endpoint). No code changes, no recompilation, no new migrations.

## Database Schema

Three core tables (the property graph) plus three config tables:

### Core Tables

```sql
-- Every node in the graph
CREATE TABLE entities (
  id UUID PRIMARY KEY,
  type TEXT NOT NULL REFERENCES entity_types(key),
  name TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Every edge in the graph
CREATE TABLE relationships (
  id UUID PRIMARY KEY,
  rel_type_key TEXT NOT NULL REFERENCES rel_types(key),
  source_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  target_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Config Tables (populated from schema.config)

```sql
CREATE TABLE entity_types (
  key TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  plural TEXT NOT NULL,
  icon TEXT,
  color TEXT NOT NULL DEFAULT '#6b7280',
  hidden BOOLEAN NOT NULL DEFAULT FALSE,
  metadata_schema JSONB,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE rel_types (
  key TEXT PRIMARY KEY,
  forward_label TEXT NOT NULL,
  reverse_label TEXT NOT NULL,
  source_types TEXT[] NOT NULL,
  target_types TEXT[] NOT NULL,
  symmetric BOOLEAN NOT NULL DEFAULT FALSE,
  metadata_schema JSONB
);

CREATE TABLE permission_rules (
  id UUID PRIMARY KEY,
  rule_type TEXT NOT NULL,
  entity_type_key TEXT REFERENCES entity_types(key),
  rel_type_key TEXT REFERENCES rel_types(key),
  config JSONB NOT NULL DEFAULT '{}'
);
```

## Schema Sync (schema.config → database)

On startup (and on admin reload), the backend:

1. Parses `schema.config`
2. Validates against a JSON Schema (entity type keys are unique, rel type source/target types reference valid entity types, etc.)
3. In a single transaction:
   - Upserts all `entity_types`
   - Upserts all `rel_types`
   - Replaces all `permission_rules`
   - Processes `auto_relationships`
4. Refreshes the in-memory cache

This means the database always reflects the config file. The config file is the source of truth.

## Caching

Schema data (entity types, rel types, permission rules) is cached in memory. The cache is:

- Populated on startup from the database
- Invalidated and refreshed on admin schema reload
- Used by all API handlers and permission checks

No TTL-based expiry needed — the cache is only refreshed when the config changes.

## Permission Resolution

All permission logic reads from the cached permission rules. The flow:

1. **Is this entity type admin-only?** Check `admin_only_entity_type` rules
2. **Can this user edit this entity?** Check `edit_granting_rel_type` rules — does the user have a relationship of that type with the entity?
3. **Does this relationship require approval?** Check `requires_approval_rel_type` rules
4. **Is this rel type admin-only?** Check `admin_only_rel_type` rules

None of this references specific entity or relationship type keys in code. It's all driven by whichever rules are in `schema.config`.

## Auto-Relationships

When an entity is created, the backend checks `auto_relationships` in the config. If there's a rule matching the entity type, it automatically creates the specified relationship. Example: creating a sprint auto-creates an `owned_by` relationship to the current user.

## Metadata Validation

Each entity type can define a `metadata_schema` (JSON Schema) in `schema.config`. When creating or updating an entity, the backend validates the metadata against this schema. Invalid metadata is rejected with a 400 error.

## Project Structure (Dart)

```
lib/
  config/
    schema_loader.dart       # Reads and validates schema.config
    schema_cache.dart        # In-memory cache for entity types, rel types, rules
  db/
    database.dart            # PostgreSQL connection
    entity_queries.dart      # CRUD for entities table
    relationship_queries.dart # CRUD for relationships table
    schema_queries.dart      # CRUD for config tables (entity_types, rel_types, etc.)
  api/
    router.dart              # Route definitions
    entity_handler.dart      # /api/entities handlers
    relationship_handler.dart # /api/relationships handlers
    schema_handler.dart      # /api/entity-types, /api/rel-types handlers
    graph_handler.dart       # /api/graph handler
    plugin_handler.dart      # /api/plugins/install, /api/plugins/export
  auth/
    auth.dart                # Authentication
    permissions.dart         # Permission resolution (reads from cache, not hardcoded)
  models/
    entity.dart
    relationship.dart
    entity_type.dart
    rel_type.dart
    permission_rule.dart
bin/
  server.dart                # Entry point — loads config, starts server
schema.config                # THE master document
```

## What the Backend Does NOT Know

- What entity types exist (it reads them from config)
- What relationship types exist (it reads them from config)
- What permission rules apply (it reads them from config)
- Whether this is an accountability tracker, a tech directory, or a grant-writing tool (it doesn't care)
