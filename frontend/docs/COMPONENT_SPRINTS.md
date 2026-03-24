# Component: Sprints Screen

## Overview

The Sprints screen shows all sprints in the system, grouped by temporal status. Each sprint links to its tasks, owner, and goal. Sprint creation auto-links ownership to the current user via the backend's `auto_relationships` config.

**Route:** `/sprints`

---

## Screen Layout

```
┌──────────────────────────────────────────────────────────────┐
│  App Shell                                                    │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Sprints                                      [+ New Sprint]  │
│                                                               │
│  ── Current ─────────────────────────────────────────────    │
│  ┌────────────────────────────────────────────────────┐      │
│  │ Sprint 12          Mar 10 – Mar 24   Robin [chip]  │      │
│  │ Goal: Ship frontend v1                              │      │
│  │ ████████░░░░░ 5/8 tasks done                        │      │
│  └────────────────────────────────────────────────────┘      │
│                                                               │
│  ── Upcoming ────────────────────────────────────────────    │
│  ┌────────────────────────────────────────────────────┐      │
│  │ Sprint 13          Mar 24 – Apr 7    Robin [chip]  │      │
│  │ Goal: Knowledge graph + polish                      │      │
│  │ 0/0 tasks                                           │      │
│  └────────────────────────────────────────────────────┘      │
│                                                               │
│  ── Completed ───────────────────────────────────────────    │
│  ┌────────────────────────────────────────────────────┐      │
│  │ Sprint 11          Feb 24 – Mar 10   Robin [chip]  │      │
│  │ Goal: Backend API complete                          │      │
│  │ ████████████ 12/12 tasks done                       │      │
│  └────────────────────────────────────────────────────┘      │
│                                                               │
│                              ┌──────────────────────────┐    │
│                              │ Sprint Detail Panel      │    │
│                              │ (desktop right panel)    │    │
│                              └──────────────────────────┘    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## Sprint Grouping

Sprints are grouped by temporal status, computed from metadata:

```dart
enum SprintTemporalStatus { current, upcoming, completed }

SprintTemporalStatus getTemporalStatus(Entity sprint) {
  final startDate = DateTime.parse(sprint.metadata['start_date']);
  final endDate = DateTime.parse(sprint.metadata['end_date']);
  final today = DateTime.now();

  if (today.isBefore(startDate)) return SprintTemporalStatus.upcoming;
  if (today.isAfter(endDate)) return SprintTemporalStatus.completed;
  return SprintTemporalStatus.current;
}
```

Within each group, sorted by `start_date` (current/upcoming: ascending, completed: descending).

---

## Sprint Card

Each sprint card in the list shows:

| Field | Source |
|-------|--------|
| Name | `entity.name` |
| Date range | `metadata.start_date` – `metadata.end_date` |
| Owner | From `owned_by` relationship → person chip (tappable) |
| Goal | `metadata.goal` |
| Task progress | Count of tasks with `in_sprint` relationship, grouped by status |

### Task Progress

To show "5/8 tasks done", we need tasks linked to this sprint:
- **With `related_to`:** `GET /api/entities?type=task&related_to=<sprintId>&rel_type=in_sprint`
- Count tasks where `metadata.status == "done"` vs total

This is an N+1 concern for the sprint list (one extra call per sprint). Options:
1. **Lazy load:** Only fetch task counts when sprint card is visible (IntersectionObserver pattern)
2. **Preload:** After fetching sprints, batch-fetch tasks for all current + upcoming sprints
3. **Accept it:** For a typical team, there are <10 active sprints — 10 extra calls is fine

Recommend option 2 for current + upcoming, option 3 for completed (only fetch on expand).

---

## Sprint Detail Panel

Shown when a sprint card is tapped.

| Viewport | Behaviour |
|----------|-----------|
| Desktop | Right panel |
| Mobile | Full page navigation |

### Content

- **Header:** Sprint name, edit/delete buttons
- **Metadata:**
  - Start date / End date (with visual timeline indicator)
  - Goal (text)
- **Owner:** Person chip (tappable → My Page)
- **Tasks:** Mini-kanban or grouped status list showing tasks in this sprint

### Tasks in Sprint

Two display options:
1. **Mini-kanban** (compact columns, no drag-and-drop) — good for 5-15 tasks
2. **Status-grouped list** (collapsed sections: backlog, todo, in_progress, review, done) — better for >15 tasks

Each task item shows: name, priority badge, assignee chip. Tappable → navigates to task detail.

**"+ Add Task to Sprint"** button → search for existing tasks, create `in_sprint` relationship.

---

## Sprint Create Form

### Fields
- **Name** (required, text input — suggest auto-naming: "Sprint 13")
- **Start Date** (required, date picker)
- **End Date** (required, date picker — must be after start date)
- **Goal** (optional, text input)

### On Submit

```
POST /api/entities { type: "sprint", name: "Sprint 13", metadata: { start_date: "2026-03-24", end_date: "2026-04-07", goal: "..." } }
```

The backend's `auto_relationships` config will auto-create an `owned_by` relationship from this sprint to the current user's person entity. No need for a manual relationship creation.

### Validation
- Name: non-empty
- Start date: required, valid date
- End date: required, valid date, must be >= start date
- Goal: optional string

---

## API Calls

```
# List all sprints
GET /api/entities?type=sprint&per_page=200

# Get sprint detail
GET /api/entities/<sprintId>
→ Returns entity + relationships (including owned_by → person)

# Get tasks in a sprint
GET /api/entities?type=task&related_to=<sprintId>&rel_type=in_sprint

# Create sprint
POST /api/entities { type: "sprint", name: "...", metadata: {...} }
→ Backend auto-creates owned_by relationship

# Add task to sprint
POST /api/relationships { rel_type_key: "in_sprint", source_entity_id: <taskId>, target_entity_id: <sprintId> }

# Update sprint
PUT /api/entities/<sprintId> { name: "...", metadata: {...} }

# Delete sprint
DELETE /api/entities/<sprintId>
```

---

## Permissions

| Action | Who Can |
|--------|---------|
| View sprint list | Any authenticated user |
| Create sprint | Any authenticated user (auto-owned) |
| Edit sprint | Admin, or sprint owner (via `owned_by` edit-granting... wait — `owned_by` is NOT in the edit-granting rules) |

**Important note:** Looking at the permission rules in `schema.config`, only `assigned_to` and `authored` are edit-granting. `owned_by` is not. This means only the sprint creator (via `created_by`) and admins can edit sprints. Sprint owners who didn't create the sprint can't edit it.

This might need a schema change (`edit_granting_rel_type: owned_by`) or it might be intentional. Flag for discussion.

---

## State

```dart
final sprintListProvider = FutureProvider.autoDispose<List<Entity>>((ref) async {
  final api = ref.read(apiClientProvider);
  final result = await api.listEntities(type: 'sprint', perPage: 200);
  return result.entities;
});
```

Sprint detail and task lists use `entityDetailProvider(sprintId)` and a sprint-specific tasks provider.

---

## Dependencies

- `PersonChip`, `StatusBadge` (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `sprintListProvider` (see [COMPONENT_STATE.md](./COMPONENT_STATE.md))
- `related_to` API enhancement for task-in-sprint queries
