# Component: My Page

## Overview

My Page is the flagship feature — every user has a personal home page showing their tasks, sprints, and documents in one view. It's the first screen you see after login, and you can visit anyone else's page too.

**Route:** `/person/:personId`

Your My Page = `/person/<your person_entity_id>`. Robin's page = `/person/<robin's person_entity_id>`.

---

## Screen Layout

```
┌──────────────────────────────────────────────────────────┐
│  App Shell (nav rail / bottom nav)                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Person Name                         [Edit] [⋮]   │   │
│  │ role: "engineer"  •  email: robin@...             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ── My Tasks ────────────────────────────────────────    │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │
│  │Backlog │ │ Todo   │ │In Prog │ │ Done   │           │
│  │        │ │        │ │        │ │        │           │
│  │ card   │ │ card   │ │ card   │ │ card   │           │
│  │ card   │ │        │ │ card   │ │        │           │
│  └────────┘ └────────┘ └────────┘ └────────┘           │
│                                          [+ New Task]    │
│                                                          │
│  ── My Sprints ──────────────────────────────────────    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Sprint 12 (Mar 10 – Mar 24)   🟢 active         │    │
│  │ Goal: Ship frontend v1                           │    │
│  │ 3/8 tasks done                                   │    │
│  ├─────────────────────────────────────────────────┤    │
│  │ Sprint 11 (Feb 24 – Mar 10)   ✅ completed       │    │
│  │ Goal: Backend API complete                       │    │
│  └─────────────────────────────────────────────────┘    │
│                                          [+ New Sprint]  │
│                                                          │
│  ── My Documents ────────────────────────────────────    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 📄 API Contract            spec    Mar 20        │    │
│  │ 📝 Sprint 12 retro notes   note    Mar 18        │    │
│  │ 📊 Q1 metrics report       report  Mar 15        │    │
│  └─────────────────────────────────────────────────┘    │
│                                        [+ New Document]  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Three Sections

### My Tasks Section

Renders a **kanban board** (reused `KanbanBoard` widget) showing only tasks assigned to this person.

- Columns: from `task.metadata_schema.status.enum` → `[backlog, todo, in_progress, review, done, archived]`
- Default visible columns: hide `archived` (collapsed toggle)
- Cards show: name, priority badge, deadline (if set), project name (from `contains_task` relationship)
- Drag-and-drop: enabled if `canEditPage(personId)` (own page or admin)
- Tap card: opens task detail (right panel on desktop, navigate on mobile)
- "+ New Task" button: visible if `canEditPage(personId)`, auto-assigns to this person

**API call:**
```
GET /api/entities?type=task&related_to=<personId>&rel_type=assigned_to
```

### My Sprints Section

Renders a **list** of sprints owned by this person, grouped by temporal status.

Grouping logic (computed from `start_date` and `end_date` metadata):
- **Current:** `start_date <= today <= end_date`
- **Upcoming:** `start_date > today`
- **Completed:** `end_date < today`

Each sprint card shows:
- Sprint name
- Date range (`start_date` – `end_date`)
- Goal (from metadata)
- Task progress: requires a sub-query — count tasks in this sprint by status

Tap sprint → navigates to sprint detail (`/sprints/:id` or opens detail panel).

"+ New Sprint" button: visible if `canEditPage(personId)`. Auto-creates `owned_by` relationship to this person (backend handles via `auto_relationships` config when creator matches).

**API call:**
```
GET /api/entities?type=sprint&related_to=<personId>&rel_type=owned_by
```

### My Documents Section

Renders a **list** of documents authored by this person.

Each row shows:
- Document name
- `doc_type` badge (spec, note, report, reference)
- Date (created_at or updated_at)
- Project name (from `contains_doc` relationship, if any)

Tap document → navigates to document detail.

"+ New Document" button: visible if `canEditPage(personId)`. Auto-creates `authored` relationship from this person to the new document.

**API call:**
```
GET /api/entities?type=document&related_to=<personId>&rel_type=authored
```

---

## Person Header

At the top of the page, show the person entity's details:
- **Name** (entity name)
- **Role** (from `metadata.role`)
- **Email** (from `metadata.email`)
- Edit button (admin only — person entities are admin-only to create/edit)

**API call:**
```
GET /api/entities/<personId>
```

This is a separate call from the three section calls. All four run in parallel on page load.

---

## Visiting Others' Pages

Any authenticated user can visit `/person/:personId` for any person. The difference is permission:

| Viewer | Can drag tasks? | Can create items? | Can edit items? |
|--------|----------------|-------------------|-----------------|
| Own page | Yes | Yes | Yes |
| Admin on any page | Yes | Yes | Yes |
| Non-admin on others' page | No (read-only kanban) | No (buttons hidden) | No |

**Navigation to others' pages:**
- Click a person chip (PersonChip widget) anywhere in the app
- PersonChip appears on task cards (assignee), sprint cards (owner), document rows (author)
- All person chips link to `/person/:personId`

---

## Data Loading

```dart
// Riverpod provider — family by personId
final myPageProvider = FutureProvider.autoDispose.family<MyPageData, String>((ref, personId) async {
  final api = ref.read(apiClientProvider);

  // 4 parallel fetches
  final results = await Future.wait([
    api.getEntity(personId),                          // person details
    api.listTasks(assigneeId: personId),              // tasks
    api.listSprints(ownerId: personId),               // sprints
    api.listDocuments(authorId: personId),             // documents
  ]);

  return MyPageData(
    person: results[0] as EntityWithRelationships,
    tasks: results[1] as PaginatedEntities,
    sprints: results[2] as PaginatedEntities,
    documents: results[3] as PaginatedEntities,
  );
});
```

### Loading States

- **Initial load:** show shimmer/skeleton for each section independently
- **Section refresh:** only reload the affected section (e.g., after creating a task, only refresh tasks)
- **Error:** show error message per section, not the whole page

---

## Task Creation from My Page

When the user clicks "+ New Task" on their own My Page:

1. Show task create form (name, metadata fields from schema)
2. On submit:
   - `POST /api/entities { type: "task", name: "...", metadata: {...} }` → creates task
   - `POST /api/relationships { rel_type_key: "assigned_to", source_entity_id: <taskId>, target_entity_id: <personId> }` → assigns to this person
3. Invalidate `myPageProvider(personId)` to refresh the tasks section

The two API calls must be sequential (need task ID from first call for the relationship).

---

## Responsive Behaviour

| Viewport | Layout |
|----------|--------|
| Desktop (>900px) | All three sections visible, kanban has all columns side-by-side, task detail opens in right panel |
| Tablet (600-900px) | Sections stack vertically, kanban scrolls horizontally |
| Mobile (<600px) | Sections stack vertically, kanban scrolls horizontally, task detail is full page navigation |

---

## Dependencies

- `KanbanBoard` widget (see [COMPONENT_KANBAN.md](./COMPONENT_KANBAN.md))
- `PersonChip`, `PriorityBadge`, `StatusBadge`, `DocTypeBadge` (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `myPageProvider` (see [COMPONENT_STATE.md](./COMPONENT_STATE.md))
- `related_to` API enhancement (see [COMPONENT_API_CLIENT.md](./COMPONENT_API_CLIENT.md))
