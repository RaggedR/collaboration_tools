# Component: Tasks Screen

## Overview

The Tasks screen is a global kanban board showing all tasks across all projects and people. It complements My Page — My Page shows "my tasks", this screen shows "all tasks". Heavy filtering keeps it manageable.

**Route:** `/tasks`

---

## Screen Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  App Shell                                                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Tasks                                              [+ New Task]     │
│                                                                      │
│  ┌─ Filter Bar ─────────────────────────────────────────────────┐   │
│  │ Project: [All ▾]  Assignee: [All ▾]  Priority: [All ▾]      │   │
│  │ Sprint: [All ▾]   Labels: [...]      [Clear Filters]        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│  │ Backlog │ │  Todo   │ │In Prog  │ │ Review  │ │  Done   │      │
│  │         │ │         │ │         │ │         │ │         │      │
│  │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │      │
│  │ │card │ │ │ │card │ │ │ │card │ │ │ │card │ │ │ │card │ │      │
│  │ └─────┘ │ │ └─────┘ │ │ └─────┘ │ │ └─────┘ │ │ └─────┘ │      │
│  │ ┌─────┐ │ │ ┌─────┐ │ │         │ │         │ │         │      │
│  │ │card │ │ │ │card │ │ │         │ │         │ │         │      │
│  │ └─────┘ │ │ └─────┘ │ │         │ │         │ │         │      │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘      │
│                                                                      │
│                              ┌────────────────────────────────┐      │
│                              │  Task Detail Panel (desktop)   │      │
│                              │                                │      │
│                              │  Task Name          [Edit][🗑] │      │
│                              │  Status: in_progress           │      │
│                              │  Priority: high                │      │
│                              │  Deadline: 2026-03-28          │      │
│                              │  Estimate: 3                   │      │
│                              │  Labels: frontend, auth        │      │
│                              │                                │      │
│                              │  Relationships:                │      │
│                              │  assigned to: Robin [chip]     │      │
│                              │  belongs to: CMS Project       │      │
│                              │  scheduled in: Sprint 12       │      │
│                              │  depends on: Login backend     │      │
│                              │                                │      │
│                              │  [+ Add Relationship]          │      │
│                              └────────────────────────────────┘      │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Kanban Board

Reuses the shared `KanbanBoard` widget (see [COMPONENT_KANBAN.md](./COMPONENT_KANBAN.md)) with:
- **All tasks** (not filtered to one person like My Page)
- Filters applied via the filter bar
- Drag-and-drop always enabled (any authenticated user can move tasks they have permission to edit)

### Columns

Derived from `task.metadata_schema.status.enum`:
```
backlog → todo → in_progress → review → done → archived
```

`archived` column is collapsed by default (toggle to show).

### Task Count Per Column

Show count in column header: `Todo (5)`

---

## Filter Bar

Each filter is a dropdown populated from data:

| Filter | Source | API Param |
|--------|--------|-----------|
| Project | `GET /api/entities?type=project` | Uses `related_to` + `rel_type=contains_task` |
| Assignee | `GET /api/entities?type=person` | Uses `related_to` + `rel_type=assigned_to` |
| Priority | Hardcoded from schema: `low, medium, high, urgent` | `metadata={"priority":"high"}` |
| Sprint | `GET /api/entities?type=sprint` | Uses `related_to` + `rel_type=in_sprint` |
| Labels | Collected from existing tasks (or freeform) | `metadata` filter (not directly supported — may need client-side filtering) |

**Combining filters:** Multiple filters apply as AND. E.g., Project="CMS" + Priority="high" shows only high-priority tasks in the CMS project.

**Clear Filters:** Resets all dropdowns to "All".

### Filter Implementation Note

Some filters (project, assignee, sprint) require the `related_to` API enhancement. Others (priority, status) use the existing `metadata` filter. Labels may need client-side filtering since the metadata `@>` operator can match array containment but the UX for multi-label filtering is complex.

---

## Task Detail Panel

Shown when a task card is tapped.

| Viewport | Behaviour |
|----------|-----------|
| Desktop (>900px) | Right panel slides in, kanban shrinks to make room |
| Mobile (<900px) | Full page navigation to `/tasks/:id` |

### Detail Content

- **Header:** Task name, edit/delete buttons (permission-gated)
- **Metadata fields:** Each field from the task's metadata, rendered as read-only with an edit toggle:
  - `status`: status badge (coloured chip)
  - `priority`: priority badge (coloured: low=grey, medium=blue, high=orange, urgent=red)
  - `deadline`: formatted date
  - `estimate`: number with unit label
  - `labels`: chip list
- **Relationships:** Grouped by type, each showing:
  - `assigned_to` → person chips (tappable → My Page)
  - `belongs to` (reverse of `contains_task`) → project name (tappable)
  - `scheduled in` (`in_sprint`) → sprint name (tappable)
  - `depends on` → task names (tappable → task detail)
  - `has subtask` (reverse of `subtask_of`) → task names (tappable)
  - `references` → document names (tappable)
- **"+ Add Relationship"** button → relationship create dialog

### Edit Mode

When "Edit" is clicked (permission-gated):
- Metadata fields become editable (same widget mapping as create form)
- Save button: `PUT /api/entities/:id { name, metadata }`
- Cancel button: discard changes

---

## Task Create Form

Triggered by "+ New Task" button or from My Page.

### Fields
- **Name** (required, text input)
- **Status** (dropdown: backlog, todo, in_progress, review, done, archived — default: backlog)
- **Priority** (dropdown: low, medium, high, urgent — optional)
- **Deadline** (date picker — optional)
- **Estimate** (number input — optional)
- **Labels** (chip input — optional)

### On Submit

```
POST /api/entities { type: "task", name: "...", metadata: { status: "backlog", priority: "high", ... } }
```

After creation, optionally prompt to assign (relationship create dialog) or auto-assign if created from My Page.

### Validation

- Name: non-empty
- Status: must be one of the enum values
- Priority: must be one of the enum values (if provided)
- Deadline: valid date format (if provided)
- Estimate: positive number (if provided)

All validated client-side before submit. Backend validates metadata against `metadata_schema` as a safety net.

---

## API Calls

```
# Load all tasks (with filters)
GET /api/entities?type=task&metadata={"status":"in_progress"}&related_to=<personId>&rel_type=assigned_to&page=1&per_page=200

# Load task detail
GET /api/entities/<taskId>
→ Returns entity + relationships

# Update task status (kanban drag)
PUT /api/entities/<taskId> { metadata: { ...existing, status: "in_progress" } }

# Create task
POST /api/entities { type: "task", name: "...", metadata: {...} }

# Assign task
POST /api/relationships { rel_type_key: "assigned_to", source_entity_id: <taskId>, target_entity_id: <personId> }
```

---

## State

```dart
final taskBoardProvider = StateNotifierProvider.autoDispose<TaskBoardNotifier, TaskBoardState>((ref) {
  return TaskBoardNotifier(ref.read(apiClientProvider), ref);
});

class TaskBoardState {
  final Map<String, List<Entity>> columns;  // "backlog" → [task1, task2, ...]
  final TaskFilters filters;
  final bool isLoading;
  final String? error;
  final String? selectedTaskId;  // for detail panel
}
```

The notifier groups tasks by `metadata['status']` into columns. When filters change, it re-fetches from the API. When a card is dragged, it does an optimistic update (see [COMPONENT_STATE.md](./COMPONENT_STATE.md)).

---

## Dependencies

- `KanbanBoard` widget (see [COMPONENT_KANBAN.md](./COMPONENT_KANBAN.md))
- `FilterBar` widget (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `MetadataForm` for task create/edit (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `RelationshipList` for task detail (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `taskBoardProvider` (see [COMPONENT_STATE.md](./COMPONENT_STATE.md))
