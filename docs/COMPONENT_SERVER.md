# Component: Server (Entry Point)

> `bin/server.dart` — wires everything together and starts listening.

## Responsibility

**Owns:**
- Reading environment variables (`PORT`, `DATABASE_URL`, `ENV`)
- Orchestrating the startup sequence (connect → migrate → validate → sync → cache → serve)
- Creating and wiring all component instances
- Starting the HTTP server

**Does NOT own:**
- Any business logic, validation, or data access (all delegated to components)

## Public Interface

```dart
// bin/server.dart

/// Entry point. Run with:
///   dart run bin/server.dart
///
/// Environment variables:
///   PORT         — HTTP port (default: 8080, 0 = OS-assigned in tests)
///   DATABASE_URL — PostgreSQL connection string
///   ENV          — 'development' | 'test' | 'production'
void main() async { ... }
```

## Dependencies

| Dependency | What it provides |
|-----------|-----------------|
| `config/schema_loader.dart` | `validate()`, `syncToDatabase()` |
| `config/schema_cache.dart` | `SchemaCache` instance |
| `db/database.dart` | `Database.connect()`, `migrate()` |
| `db/entity_queries.dart` | `EntityQueries` constructor |
| `db/relationship_queries.dart` | `RelationshipQueries` constructor |
| `db/schema_queries.dart` | `SchemaQueries` constructor |
| `auth/auth.dart` | Auth middleware |
| `auth/permissions.dart` | `PermissionResolver` constructor |
| `api/router.dart` | Route setup |

## Dependents

| Dependent | What it uses |
|-----------|-------------|
| `test/helpers/test_server.dart` | Spawns `dart run bin/server.dart` as a subprocess with test environment variables |

## Startup Sequence

```
1. Read environment variables (PORT, DATABASE_URL, ENV)
       ↓
2. Database.connect(DATABASE_URL)
       ↓
3. db.migrate()
   Create tables if they don't exist:
   entities, relationships, entity_types, rel_types, permission_rules
       ↓
4. Read and parse schema.config from filesystem
       ↓
5. SchemaLoader.validate(config)
   If invalid → log errors and exit
       ↓
6. SchemaLoader.syncToDatabase(config, db)
   In a single transaction:
   - Upsert entity_types
   - Upsert rel_types
   - Replace permission_rules
   - Process auto_relationships
       ↓
7. SchemaCache.refresh(config)
   Populate in-memory cache
       ↓
8. Construct query classes:
   - SchemaQueries(db: db)
   - EntityQueries(db: db, cache: cache)
   - RelationshipQueries(db: db, cache: cache)
       ↓
9. Construct PermissionResolver(rules: cache.permissionRules)
       ↓
10. Set up router with handlers, passing in query classes + resolver
        ↓
11. Start HTTP server on PORT
    Log: "Server listening on port $PORT"
```

## Error Handling

| Phase | Error | Behaviour |
|-------|-------|-----------|
| Database connection | Connection refused | Crash with error message |
| Migration | SQL error | Crash with error message |
| Schema validation | Invalid `schema.config` | Log all validation errors, exit |
| Schema sync | Database error | Crash (transaction rolled back) |
| Runtime | Unhandled exception in handler | 500 Internal Server Error |

The server is designed to fail fast on startup — if any configuration step fails, it exits rather than starting in a broken state.

## Key Design Decisions

1. **Fail-fast startup** — if `schema.config` is invalid or the database is unreachable, the server exits immediately. No partial startup, no degraded mode. This is the safest behaviour for a config-driven system.

2. **All wiring happens in `main()`** — there's no dependency injection container. Components are constructed explicitly and passed to their dependents. This keeps the startup sequence readable and debuggable.

3. **Test server spawns a real process** — `TestServer` in `test/helpers/test_server.dart` runs `dart run bin/server.dart` as a subprocess with `PORT=0` (OS picks a free port) and `DATABASE_URL` pointing to the test database. This tests the real startup sequence, not a mock.

4. **Schema is read from filesystem, not the database** — the server always reads `schema.config` from disk on startup and syncs it into the database. The database is a downstream mirror, not the source of truth.

## Test Coverage

| Test File | What it covers |
|-----------|---------------|
| `test/helpers/test_server.dart` | `TestServer` class that manages server process lifecycle for E2E tests — start (with health check polling), stop |
| All `test/e2e/*.dart` tests | Exercise the full startup sequence indirectly by running against a real server instance |
