# Component: Kanban Board Widget

## Overview

The kanban board is a **reusable widget** shared between My Page (filtered to one person) and the Tasks screen (all tasks). It renders tasks as cards in status columns with drag-and-drop to change status. The widget is stateless regarding data — it receives tasks, columns, and callbacks from its parent.

---

## Widget Interface

```dart
class KanbanBoard extends StatelessWidget {
  /// Tasks grouped by status column.
  final Map<String, List<Entity>> columns;

  /// Column order (e.g., ["backlog", "todo", "in_progress", "review", "done"]).
  final List<String> columnOrder;

  /// Column display names (e.g., {"in_progress": "In Progress"}).
  final Map<String, String> columnLabels;

  /// Called when a card is dragged to a new column.
  /// Parent is responsible for API calls and state updates.
  final void Function(String taskId, String fromStatus, String toStatus)? onStatusChange;

  /// Called when a card is tapped.
  final void Function(Entity task)? onTaskTap;

  /// If true, disables drag-and-drop (read-only mode for visiting others' pages).
  final bool readOnly;

  /// Columns to hide by default (e.g., ["archived"]).
  final List<String> collapsedColumns;
}
```

### Usage on My Page

```dart
KanbanBoard(
  columns: myPageState.tasksByStatus,
  columnOrder: ['backlog', 'todo', 'in_progress', 'review', 'done'],
  columnLabels: statusLabels,  // from schema
  onStatusChange: canEditPage ? (id, from, to) => ref.read(myPageProvider(personId).notifier).moveTask(id, from, to) : null,
  onTaskTap: (task) => openTaskDetail(task.id),
  readOnly: !canEditPage,
  collapsedColumns: ['archived'],
)
```

### Usage on Tasks Screen

```dart
KanbanBoard(
  columns: taskBoardState.columns,
  columnOrder: ['backlog', 'todo', 'in_progress', 'review', 'done'],
  columnLabels: statusLabels,
  onStatusChange: (id, from, to) => ref.read(taskBoardProvider.notifier).moveTask(id, from, to),
  onTaskTap: (task) => selectTask(task.id),
  readOnly: false,
  collapsedColumns: ['archived'],
)
```

---

## Kanban Column

```dart
class KanbanColumn extends StatelessWidget {
  final String status;
  final String label;
  final List<Entity> tasks;
  final bool isCollapsed;
  final void Function()? onToggleCollapse;
  final void Function(Entity task)? onTaskTap;
  final bool acceptsDrop;  // false in readOnly mode
}
```

### Column Header

```
┌─────────────────────────┐
│  In Progress  (3)   ▼   │   ← label, count, collapse toggle
├─────────────────────────┤
│  ┌───────────────────┐  │
│  │  card              │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │  card              │  │
│  └───────────────────┘  │
│                         │
│                         │   ← drop zone (visual feedback on drag-over)
└─────────────────────────┘
```

Collapsed column shows only the header with count, no cards.

---

## Kanban Card

```dart
class KanbanCard extends StatelessWidget {
  final Entity task;
  final void Function()? onTap;
  final bool isDraggable;  // false in readOnly mode
}
```

### Card Layout

```
┌─────────────────────────┐
│ Implement login page     │   ← task name (1-2 lines, overflow ellipsis)
│                          │
│ 🔴 urgent   Robin [ava] │   ← priority badge + assignee chip
│ 📅 Mar 28   CMS Project │   ← deadline (if set) + project name
└─────────────────────────┘
```

| Element | Source | Display |
|---------|--------|---------|
| Name | `entity.name` | Text, max 2 lines |
| Priority | `metadata.priority` | `PriorityBadge` widget (coloured dot + text) |
| Assignee | From `assigned_to` relationship | `PersonChip` (small avatar + name) |
| Deadline | `metadata.deadline` | Date, red if overdue |
| Project | From `contains_task` relationship (reverse) | Text label |

**Note:** The card needs relationship data (assignee, project) which isn't in the entity list response. Options:
1. Fetch full entity detail for each card — expensive, N+1
2. Only show metadata fields on cards, show relationships in detail panel — simpler
3. Add relationship data to the list response (backend enhancement) — ideal but scope creep

**Recommendation:** Option 2 for v1. Cards show name, priority, deadline, labels. Assignee and project show in the detail panel. Upgrade to option 3 later if needed.

---

## Drag-and-Drop

### Library Choice: `appflowy_board`

Evaluate `appflowy_board` first — it's built for kanban:
- Multi-column board with drag between columns
- Card reordering within columns
- Built-in scroll management
- Active maintenance

If `appflowy_board` doesn't fit, fall back to Flutter's built-in `Draggable` + `DragTarget`:
- More work but full control
- Needs manual: scroll-during-drag, drop zone highlighting, card animation

### Drag Flow

```
1. User long-presses (mobile) or clicks-and-drags (desktop) a card
2. Card lifts with a shadow (Material elevation effect)
3. Original position shows a placeholder (greyed out)
4. Columns highlight when a valid drop target is hovered
5. User releases:
   a. On a different column → onStatusChange callback fires
   b. On the same column → no-op (or reorder within column)
   c. Outside any column → card snaps back (cancelled)
```

### Optimistic Update Pattern

The `onStatusChange` callback triggers the parent's state notifier, which:
1. Moves the card in local state immediately (UI updates)
2. Fires `PUT /api/entities/:id` to update status
3. On failure: rolls back the card to its original column

See [COMPONENT_STATE.md](./COMPONENT_STATE.md) for the full optimistic update implementation.

---

## Responsive Behaviour

| Viewport | Layout |
|----------|--------|
| Desktop (>1200px) | All columns visible side-by-side, cards have full detail |
| Tablet (600-1200px) | Columns scroll horizontally, cards show name + priority |
| Mobile (<600px) | Columns scroll horizontally (one column visible at a time), cards compact |

### Horizontal Scroll

On narrow viewports, the board scrolls horizontally. Each column has a minimum width (250px desktop, 200px mobile). The board uses a `SingleChildScrollView` with `Axis.horizontal`.

### Touch vs Mouse

- **Touch (mobile):** Long-press to start drag (to avoid conflict with scroll)
- **Mouse (desktop):** Click-and-drag immediately

---

## Column Configuration

Columns are derived from the task entity type's `metadata_schema.status.enum`:

```dart
// Read from schema
final taskType = schema.entityTypes.firstWhere((t) => t.key == 'task');
final statusEnum = taskType.metadataSchema['properties']['status']['enum'] as List;
// → ["backlog", "todo", "in_progress", "review", "done", "archived"]

// Column labels (humanize the enum values)
final columnLabels = {
  'backlog': 'Backlog',
  'todo': 'Todo',
  'in_progress': 'In Progress',
  'review': 'Review',
  'done': 'Done',
  'archived': 'Archived',
};
```

This is one of the few places where schema data drives UI structure — the column names come from the schema, but the kanban layout itself is hardcoded.

---

## Empty States

- **Empty column:** Show subtle "No tasks" text or just empty space
- **Empty board:** "No tasks found. Create your first task to get started." with a CTA button
- **All filtered out:** "No tasks match your filters." with a "Clear filters" link

---

## Performance

- Each card is a lightweight widget — avoid rebuilding the entire board on single-card changes
- Use `const` constructors where possible
- For boards with >100 cards: consider lazy-loading cards within columns (rare case)
- The board itself should be a `const` if props haven't changed

---

## Dependencies

- `PriorityBadge`, `PersonChip` (see [COMPONENT_SHARED_WIDGETS.md](./COMPONENT_SHARED_WIDGETS.md))
- `appflowy_board` package (or built-in `Draggable`/`DragTarget`)
- Task entity type from schema (for column configuration)
