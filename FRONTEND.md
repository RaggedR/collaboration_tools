# Frontend Design (Flutter)

## Core Principle

The Flutter app is a **generic CMS client**. It has no hardcoded knowledge of entity types, relationship types, or permission rules. Everything is discovered at runtime from the API, which in turn reflects `schema.config`.

To change what the app displays — add a new entity type, change colours, rename a relationship — you edit `schema.config` on the backend. The frontend adapts automatically.

## Startup Flow

```
App launches
  → GET /api/schema
  → Store schema in app state (entity types, rel types, permission rules, app config)
  → Build navigation from entity types (one list screen per non-hidden entity type)
  → Apply branding from app config (name, theme colour)
  → Ready
```

If the schema fetch fails, the app shows an error screen. No schema = no app.

## Screen Architecture

Every screen is generic. None reference specific entity type keys.

### 1. Navigation Sidebar / Bottom Nav

Built from `entity_types` array:
- One entry per non-hidden entity type
- Uses `label` (or `plural`) as the nav label
- Uses `icon` and `color` from the entity type config
- Sorted by `sort_order` (if provided) or alphabetically

### 2. Entity List Screen

A single reusable screen that lists entities of a given type.

- **Route:** `/entities/:type` (e.g. `/entities/task`, `/entities/sprint`)
- **Data:** `GET /api/entities?type=:type`
- **Features:**
  - Search bar (uses `search` query param)
  - Filter by metadata fields (built from `metadata_schema` — e.g. status dropdown, priority dropdown)
  - Sort by name, created_at, or metadata fields
  - Pagination
  - FAB to create new entity (hidden if entity type is admin-only and user is not admin)

### 3. Entity Detail Screen

Shows a single entity with its metadata and relationships.

- **Route:** `/entities/:type/:id`
- **Data:** `GET /api/entities/:id` (returns entity + relationships)
- **Sections:**
  - **Header:** Entity name, type badge (with icon + colour)
  - **Metadata:** Rendered as a form/card from `metadata_schema`. Each field type maps to a widget:
    - `string` → text field
    - `string` with `enum` → dropdown
    - `string` with `format: "date"` → date picker
    - `number` → number field
    - `array` of strings → chip input
  - **Relationships:** Grouped by rel type. Each group shows:
    - The relationship label (forward or reverse depending on direction)
    - List of related entities (tappable → navigates to their detail screen)
    - "Add" button to create a new relationship of that type
  - **Edit button:** Visible only if user has edit permission
  - **Delete button:** Visible only if user has delete permission

### 4. Entity Create/Edit Form

A generic form built from the entity type's `metadata_schema`.

- Entity name (always present)
- Metadata fields rendered from the JSON Schema (same widget mapping as detail screen)
- On save: `POST /api/entities` (create) or `PUT /api/entities/:id` (edit)
- Validates locally against `metadata_schema` before submitting

### 5. Relationship Create Dialog

When adding a relationship from an entity detail screen:

1. User picks a rel type from available options (filtered: only rel types where this entity's type is in `source_types` or `target_types`)
2. User searches for and selects the target entity (type-filtered based on the rel type)
3. Backend creates the relationship

### 6. Kanban Board (special view for entities with status)

If an entity type has a `status` field with an `enum` in its `metadata_schema`, the list screen offers a toggle between **list view** and **board view**.

Board view:
- One column per enum value
- Cards show entity name + key metadata
- Drag-and-drop moves a card = PATCH entity metadata to update status
- This works for tasks, projects, or any entity type that has a status enum — the frontend doesn't care which type it is

### 7. Knowledge Graph Screen

- **Route:** `/graph`
- **Data:** `GET /api/graph`
- Renders an interactive force-directed graph (using a Flutter graph library or WebView with d3)
- Nodes coloured by entity type (using `color` from schema)
- Edges labelled by relationship type
- Tap a node → navigate to entity detail
- Filter panel: toggle entity types on/off, filter by relationship type

### 8. Admin: Schema Editor

- **Route:** `/admin/schema`
- **Only visible to admin users**
- Three tabs:
  - **Entity Types** — list, add, edit, delete entity types
  - **Relationship Types** — list, add, edit, delete rel types
  - **Permission Rules** — list, add, delete rules
- Changes here hit the backend admin endpoints, which update `schema.config` and reload
- After saving, the app re-fetches `/api/schema` and rebuilds navigation

## State Management

```
SchemaState (loaded once on startup, refreshed on admin changes)
  ├── app config (name, theme, logo)
  ├── entity types[]
  ├── rel types[]
  └── permission rules[]

AuthState
  ├── current user
  └── is admin?

EntityListState (per entity type)
  ├── entities[]
  ├── filters
  ├── pagination
  └── loading state

EntityDetailState
  ├── entity
  ├── relationships[]
  └── loading state
```

## How schema.config Changes Flow Through

```
Developer edits schema.config
  → Backend restarts (or admin hits reload)
  → Backend syncs config into database
  → Frontend fetches GET /api/schema
  → Navigation rebuilds (new entity types appear, removed ones disappear)
  → Entity forms rebuild (new metadata fields appear)
  → Relationship options update
  → Permission checks update
  → No Flutter code changes needed
```

## What the Frontend Does NOT Know

- What entity types exist (it reads them from `/api/schema`)
- What relationships are valid (it reads constraints from `/api/schema`)
- What permissions apply (it reads rules from `/api/schema`)
- Whether this is an accountability tracker or a grant-writing tool (it doesn't care)
- The name of the app (it reads it from `app.name`)
- The theme colour (it reads it from `app.theme_color`)

## Nick's Deliverables

1. Generic entity list screen (with search, filter, pagination)
2. Generic entity detail screen (with metadata card + relationship list)
3. Generic entity create/edit form (built from JSON Schema)
4. Relationship create dialog
5. Kanban board view (for any entity type with a status enum)
6. Knowledge graph visualisation
7. Schema editor (admin only)
8. Navigation builder (reads entity types, builds sidebar/tabs)
9. App shell with branding from schema
