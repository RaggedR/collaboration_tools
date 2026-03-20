# CMS-Abstract: Preliminary Ideas

## The Insight

melb-tech (RaggedR/melb-tech) already implements the exact three-table property graph architecture that Robin and Nick designed from scratch for their CMS:

- `entities` table with JSONB metadata
- `relationships` table with type constraints and auto-swap
- `rel_types` table with forward/reverse labels

Plus: admin auth, permissions, relationship request/approval workflow, notifications, 180 E2E tests, and a knowledge graph visualisation.

## The Goal

Build a generic CMS engine where:

1. Entity types and relationship types are created via an admin panel, not hardcoded
2. Permission rules are configured via the admin panel, not hardcoded in config files
3. Specific use cases (e.g. "melb-tech", "grant-writing", "tech-world") are plugins — JSON configurations that bootstrap the CMS for that domain

## Stack

- **Backend:** Dart (Robin)
- **Frontend:** Flutter (Nick)
- **Architecture:** Single configurable API — no separate "abstract" and "use-case" layers

## What's Currently Hardcoded (Must Become Dynamic)

- **Entity types** — CHECK constraint on `entities` table + `ENTITY_TYPE_CONFIG` in `lib/config/schema.ts`
- **Relationship type definitions** — `REL_TYPE_DEFINITIONS` in `lib/config/schema.ts` (duplicates what's in the DB `rel_types` table)
- **Auto-relationship map** — `AUTO_RELATIONSHIP_MAP` in `lib/config/schema.ts`
- **Permission arrays** — `ADMIN_ONLY_ENTITY_TYPES`, `EDIT_GRANTING_REL_TYPES`, `ADMIN_ONLY_REL_TYPES`, `REQUIRES_APPROVAL_REL_TYPES` in `lib/config/permissions.ts`

## What's Already Dynamic (Keep As-Is)

- `rel_types` table with CRUD API
- Entity/relationship CRUD APIs
- Graph data API
- Auth, sessions, permission resolution
- Relationship request/approval workflow
- Notifications (in-app + email)
- 180 E2E tests

## Rough Phases

1. **Fork & audit** — map all imports of hardcoded config, extract melb-tech config into a reference plugin JSON
2. **Entity types to DB** — new `entity_types` table, API, cached accessor replacing `ENTITY_TYPE_CONFIG`
3. **Permission rules to DB** — new `permission_rules` table, API, cached accessor replacing hardcoded arrays
4. **Meta-admin panel** — `/admin/schema` page for managing entity types, rel types, and permission rules
5. **Plugin system** — JSON format for bootstrapping a CMS instance, CLI installer, import/export via admin UI
6. **Cleanup** — delete old hardcoded config, verify all 180 tests still pass

## Example Plugin Use Cases

- **melb-tech** — Melbourne tech community directory (the original)
- **grant-writing** — entity types: grant, section, funder, document; rel types: contains, supports, assigned_to, revision_of
- **tech-world** — Adventures in Tech World content; entity types: source, guard, gate, challenge, concept, path, map

## Architecture Decision: Single API, Not Two Layers

### Options Considered

**Option A — Two-layer API:** Flutter → Use-Case API (e.g. grant-writing) → Abstract CMS API.
The use-case API translates domain language ("create a grant") into generic operations ("create entity of type 'grant'").

**Option B — Single configurable API:** Flutter → CMS API (configured via plugin).
One API that knows about entity types, permission rules, and rel types because they're in the database. The plugin populates those tables. No wrapper layer.

### Decision: Option B (single API)

A two-layer API means two things to deploy and the use-case layer is mostly pass-through. The generic API already handles "create entity of type 'grant'" — a domain wrapper adds little.

**Where does domain-specific logic live?** In configuration: `permission_rules` and `auto_relationship` rules in the database. If truly custom behaviour is needed later (e.g. "when a grant is submitted, auto-create a review entity"), that becomes a server-side hook — not a whole second API.

## API Contract (Draft)

These are the endpoints Nick's Flutter app codes against. The app doesn't need to know whether the backend is configured for "grant-writing" or "melb-tech" — the schema endpoints tell it everything.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/entity-types` | Schema discovery — what entity types exist, with labels, icons, colours |
| `GET` | `/api/rel-types` | What relationship types exist |
| `GET/POST/PUT/DELETE` | `/api/entities` | CRUD entities |
| `GET/POST/PUT/DELETE` | `/api/relationships` | CRUD relationships |
| `GET` | `/api/graph` | Knowledge graph data |
| `GET` | `/api/permission-rules` | What rules apply (for UI gating) |
| `POST` | `/api/plugins/install` | Install a plugin (admin-only) |
| `GET` | `/api/plugins/export` | Export current config as plugin JSON |

## Configurable Frontend

Nick builds **one Flutter app** that configures itself from the API:

1. **Fetch schema on startup** — `GET /api/entity-types` and `GET /api/rel-types` tell the app what types exist, their labels, icons, colours
2. **Render generically** — entity list screens, detail screens, relationship editors are all driven by schema data, not hardcoded per type
3. **Use-case branding** — the plugin could include a `ui` section (app name, theme colours, logo) that the Flutter app reads on init

A new use case = install a new plugin JSON on the backend, and the frontend adapts automatically.

## Key Design Decisions (To Confirm)

- **Caching strategy** — 60s TTL in-memory cache for entity types and permission rules?
- **Plugin format** — data-only JSON (no code execution)?
- **Symmetric relationships** — add `symmetric` flag to `rel_types`?
- **Meta-admin location** — separate `/admin/schema` route?

## Open Questions

- Should plugins support seed data (sample entities/relationships)?
- Plugin UI config — what branding fields should it include (app name, theme, logo)?
- How should the Flutter app handle schema changes at runtime (re-fetch on focus, push notification, polling)?
