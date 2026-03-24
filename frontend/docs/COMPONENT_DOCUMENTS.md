# Component: Documents Screen

## Overview

The Documents screen provides a searchable, filterable list of all documents (specs, notes, reports, references). Documents are the knowledge layer — they connect to tasks, projects, and people through relationships.

**Route:** `/documents`

---

## Screen Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  App Shell                                                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Documents                                    [+ New Document]    │
│                                                                   │
│  ┌─ Filter / Search ─────────────────────────────────────────┐   │
│  │ 🔍 [Search by name...        ]                             │   │
│  │ Type: [All ▾]  Project: [All ▾]  Author: [All ▾]          │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ 📋 API Contract             spec     CMS Project  Mar 20  │   │
│  │ 📋 Frontend Architecture    spec     CMS Project  Mar 21  │   │
│  │ 📝 Sprint 12 retro notes   note     —            Mar 18  │   │
│  │ 📊 Q1 metrics report       report   —            Mar 15  │   │
│  │ 📚 Dart shelf docs         reference —            Mar 10  │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Showing 1–5 of 12               [< Prev] [Next >]              │
│                                                                   │
│                          ┌────────────────────────────────────┐  │
│                          │  Document Detail Panel             │  │
│                          │                                    │  │
│                          │  API Contract            [Edit][🗑]│  │
│                          │  Type: spec                        │  │
│                          │  URL: (link)                       │  │
│                          │  Labels: api, backend              │  │
│                          │                                    │  │
│                          │  Relationships:                    │  │
│                          │  authored by: Robin [chip]         │  │
│                          │  belongs to: CMS Project           │  │
│                          │  referenced by: Task "API tests"   │  │
│                          │                                    │  │
│                          │  [+ Add Relationship]              │  │
│                          └────────────────────────────────────┘  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Document List

A paginated, searchable list (not a kanban — documents don't have a status workflow).

### Columns / Fields per Row

| Field | Source | Display |
|-------|--------|---------|
| Name | `entity.name` | Text, tappable → detail |
| Doc type | `metadata.doc_type` | Coloured badge (spec=blue, note=green, report=orange, reference=grey) |
| Project | From `contains_doc` relationship (reverse) | Text or "—" if unlinked |
| Date | `entity.updated_at` | Relative or absolute date |

### Search

Uses the API's `search` parameter:
```
GET /api/entities?type=document&search=<query>
```

Debounce: 300ms after last keystroke.

### Filters

| Filter | Source | API Implementation |
|--------|--------|-------------------|
| Doc type | Hardcoded from schema: `spec, note, report, reference` | `metadata={"doc_type":"spec"}` |
| Project | `GET /api/entities?type=project` | `related_to=<projectId>&rel_type=contains_doc` |
| Author | `GET /api/entities?type=person` | `related_to=<personId>&rel_type=authored` |

Filters combine as AND with search.

### Pagination

- Default: 50 per page
- Show "Showing 1–50 of 142" with prev/next navigation
- Uses API `page` and `per_page` params

---

## Document Detail Panel

| Viewport | Behaviour |
|----------|-----------|
| Desktop | Right panel |
| Mobile | Full page navigation |

### Content

- **Header:** Document name, edit/delete buttons (permission-gated)
- **Metadata:**
  - `doc_type`: badge
  - `url`: clickable link (if present) — opens in browser
  - `labels`: chip list
- **Relationships:**
  - `authored by` (reverse of `authored`) → person chip(s)
  - `belongs to` (reverse of `contains_doc`) → project name
  - `referenced by` (reverse of `references`) → task names

### Edit Mode

When "Edit" is clicked:
- Name becomes editable text field
- `doc_type` becomes dropdown
- `url` becomes text input
- `labels` becomes chip input
- Save: `PUT /api/entities/:id { name, metadata }`

---

## Document Create Form

### Fields
- **Name** (required)
- **Doc Type** (dropdown: spec, note, report, reference — optional but recommended)
- **URL** (text input, validated as URI — optional)
- **Labels** (chip input — optional)

### On Submit

```
POST /api/entities { type: "document", name: "...", metadata: { doc_type: "spec", url: "...", labels: [...] } }
```

After creation:
- If created from My Page: auto-create `authored` relationship from current user's person entity
- If created from Documents screen: prompt to add relationships (author, project)

---

## Permissions

| Action | Who Can |
|--------|---------|
| View documents | Any authenticated user |
| Create document | Any authenticated user |
| Edit document | Admin, creator (`created_by`), or author (via `authored` edit-granting rel) |
| Delete document | Admin, creator |

The `authored` relationship is edit-granting per `schema.config`. This means if Robin is linked as author of a document (even if someone else created the entity), Robin can edit it.

---

## API Calls

```
# List documents (with filters + search)
GET /api/entities?type=document&search=API&metadata={"doc_type":"spec"}&related_to=<projectId>&rel_type=contains_doc&page=1&per_page=50

# Get document detail
GET /api/entities/<docId>

# Create document
POST /api/entities { type: "document", name: "...", metadata: {...} }

# Link author
POST /api/relationships { rel_type_key: "authored", source_entity_id: <personId>, target_entity_id: <docId> }

# Link to project
POST /api/relationships { rel_type_key: "contains_doc", source_entity_id: <projectId>, target_entity_id: <docId> }

# Update document
PUT /api/entities/<docId> { name: "...", metadata: {...} }
```

---

## State

```dart
final documentListProvider = FutureProvider.autoDispose.family<PaginatedEntities, DocumentFilters>((ref, filters) async {
  final api = ref.read(apiClientProvider);
  return api.listDocuments(
    docType: filters.docType,
    authorId: filters.authorId,
    projectId: filters.projectId,
    page: filters.page,
  );
});
```

---

## Dependencies

- `DocTypeBadge`, `PersonChip`, `SearchBar`, `FilterBar`, `PaginatedList` (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `MetadataForm` for create/edit (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `RelationshipList` for detail panel (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
