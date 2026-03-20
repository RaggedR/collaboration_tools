# Permissions & Auth Design Decisions

> How users, persons, admin status, and permission resolution work — decisions made 2026-03-20, informed by melb-tech production patterns.

## Packages

- **PostgreSQL driver:** `postgres` (raw SQL, no ORM)
- **HTTP framework:** `shelf` + `shelf_router`

## Users Table

Separate from `person` entities. Follows the melb-tech pattern (`users` table with FK to `entities`), adapted for self-serve registration instead of claim-based onboarding.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  person_entity_id UUID UNIQUE REFERENCES entities(id),
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Registration Flow

melb-tech creates person entities first (admin-curated), then users claim them. Outlier inverts this — registration creates both atomically:

1. `POST /api/auth/register { email, password, name }`
2. Create `users` row (password hashed with bcrypt)
3. Auto-create `person` entity with `{ email, role: 'member' }` metadata
4. Link `users.person_entity_id → person.id`
5. Return JWT token

The `person` entity type is `admin_only_entity_type` in `schema.config`, but registration bypasses this (it's the one exception — the system creates the person, not the user).

## Authentication

- **JWT** (not server-side sessions like melb-tech) — already specified in API.md as `Authorization: Bearer <token>`
- Token issued on register and login
- `GET /api/auth/me` returns current user info

## Admin Assignment

`is_admin` boolean on `users` table, same as melb-tech.

- **Development:** First registered user gets `is_admin = TRUE`
- **Production:** CLI script (like melb-tech's `create-admin`) or direct DB update

No self-promotion path. Admin status is never granted through the API.

## current_user Resolution

When `auto_relationships` in `schema.config` specifies `"target": "current_user"`, the system resolves it as:

```
JWT token → users.id → users.person_entity_id → person entity
```

Example: creating a sprint triggers `auto_relationships` rule → creates `owned_by` relationship from the sprint to the current user's person entity.

## Permission Model

Simpler than melb-tech. No `entity_permissions` table, no owner/editor grants, no multi-profile support.

### What Outlier Has

Two rule types from `schema.config`, resolved by `PermissionResolver`:

| Rule Type | Effect |
|-----------|--------|
| `admin_only_entity_type` | Only admins can create entities of this type |
| `edit_granting_rel_type` | Users with this relationship to an entity can edit it |

### What melb-tech Has (that Outlier doesn't need yet)

| Feature | Why not now |
|---------|------------|
| `entity_permissions` table (owner/editor grants) | Relationship-based permissions are sufficient for the accountability tracker |
| `user_persons` junction table (multi-profile) | No use case for one user owning multiple person profiles |
| `frozen_at` on users (claim disputes) | No claim flow, no disputes |
| `requires_approval_rel_type` rule enforcement | Designed in `schema.config` but not needed for v1 |

These can be added later without schema changes — the permission model is additive.

## How melb-tech Informed These Decisions

melb-tech is the production predecessor (Next.js + PostgreSQL, deployed on Cloud Run, 180+ E2E tests). Its three-table property graph pattern (`entities`, `relationships`, `rel_types`) was extracted into Outlier's configurable CMS engine. The key differences:

| Concern | melb-tech | Outlier |
|---------|-----------|---------|
| Entity/rel type definitions | Hardcoded in TypeScript config | Database tables from `schema.config` |
| Permission rules | Hardcoded arrays | Database tables from `schema.config` |
| User onboarding | Admin creates person → user claims | Registration creates both |
| Auth mechanism | Server-side sessions + cookies | JWT + Bearer header |
| Permission granularity | admin > owner > editor > derived > self | admin > relationship-derived |
