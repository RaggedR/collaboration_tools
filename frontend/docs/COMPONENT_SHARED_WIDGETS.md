# Component: Reusable Widgets

## Overview

Shared widgets are the building blocks used across all screens. They're mostly stateless (receive data via props, emit events via callbacks). The one exception is `MetadataForm`, which manages its own form state.

---

## Badges

### PriorityBadge

Displays task priority as a coloured chip.

```dart
class PriorityBadge extends StatelessWidget {
  final String priority; // "low", "medium", "high", "urgent"
}
```

| Priority | Colour | Icon |
|----------|--------|------|
| low | Grey (`#9ca3af`) | `arrow_downward` |
| medium | Blue (`#3b82f6`) | `remove` (dash) |
| high | Orange (`#f97316`) | `arrow_upward` |
| urgent | Red (`#ef4444`) | `priority_high` |

Renders as: `[icon] priority_text` in a compact chip.

### StatusBadge

Displays task status as a coloured chip.

```dart
class StatusBadge extends StatelessWidget {
  final String status; // "backlog", "todo", "in_progress", "review", "done", "archived"
}
```

| Status | Colour | Display |
|--------|--------|---------|
| backlog | Grey | Backlog |
| todo | Blue | Todo |
| in_progress | Yellow/Amber | In Progress |
| review | Purple | Review |
| done | Green | Done |
| archived | Dark Grey | Archived |

### DocTypeBadge

Displays document type as a coloured chip.

```dart
class DocTypeBadge extends StatelessWidget {
  final String docType; // "spec", "note", "report", "reference"
}
```

| Type | Colour | Icon |
|------|--------|------|
| spec | Blue (`#3b82f6`) | `article` |
| note | Green (`#10b981`) | `edit_note` |
| report | Orange (`#f97316`) | `assessment` |
| reference | Grey (`#6b7280`) | `menu_book` |

---

## PersonChip

Displays a person entity as a tappable chip. Used everywhere someone is referenced (task assignee, sprint owner, document author).

```dart
class PersonChip extends StatelessWidget {
  final String personId;
  final String name;
  final void Function()? onTap; // typically: navigate to /person/:personId
}
```

Renders as: `[avatar_circle] Name` — small, inline, tappable. Avatar is first letter of name on a coloured background (person entity colour: `#ec4899`).

Tapping navigates to `/person/:personId` (My Page).

---

## EntityCard

A generic card for displaying any entity in a list context. Used on My Page sections and as a base for more specific cards.

```dart
class EntityCard extends StatelessWidget {
  final Entity entity;
  final void Function()? onTap;
  final Widget? trailing;     // e.g., a badge or date
  final Widget? subtitle;     // e.g., metadata summary
}
```

Renders:
```
┌──────────────────────────────────────────────┐
│ [type_icon]  Entity Name          trailing   │
│              subtitle                         │
└──────────────────────────────────────────────┘
```

The type icon and colour come from the schema's entity type config.

---

## MetadataForm

The **one generic widget** — it builds a form dynamically from a `metadata_schema` JSON Schema. This is where the schema-driven nature shows up in the frontend.

```dart
class MetadataForm extends StatefulWidget {
  /// The JSON Schema for this entity type's metadata.
  final Map<String, dynamic> metadataSchema;

  /// Current metadata values (for edit mode). Null for create mode.
  final Map<String, dynamic>? initialValues;

  /// Called when the form is submitted with valid data.
  final void Function(Map<String, dynamic> metadata) onSubmit;

  /// Whether to include the entity name field.
  final bool includeNameField;

  /// Initial name value (for edit mode).
  final String? initialName;
}
```

### Field Type Mapping

Based on the JSON Schema `type`, `enum`, and `format` of each property:

| Schema | Widget |
|--------|--------|
| `{ "type": "string" }` | `TextFormField` |
| `{ "type": "string", "enum": [...] }` | `DropdownButtonFormField` |
| `{ "type": "string", "format": "date" }` | `DatePicker` (tapping opens `showDatePicker`) |
| `{ "type": "string", "format": "email" }` | `TextFormField` with email keyboard |
| `{ "type": "string", "format": "uri" }` | `TextFormField` with URL keyboard |
| `{ "type": "number" }` | `TextFormField` with number keyboard |
| `{ "type": "array", "items": { "type": "string" } }` | Chip input (type text, press enter to add chip) |

### Validation

- **Required fields:** `metadataSchema.required` array → field cannot be empty
- **Enum values:** dropdown restricts to valid options
- **Date format:** validated by date picker
- **URI format:** basic URL validation regex
- **Number type:** must parse as num

Validation runs on form submit. Individual fields validate on blur (focus lost).

### Example: Task Create Form

Given task's `metadata_schema`:
```json
{
  "type": "object",
  "properties": {
    "status": { "type": "string", "enum": ["backlog", "todo", "in_progress", "review", "done", "archived"] },
    "priority": { "type": "string", "enum": ["low", "medium", "high", "urgent"] },
    "deadline": { "type": "string", "format": "date" },
    "estimate": { "type": "number" },
    "labels": { "type": "array", "items": { "type": "string" } }
  }
}
```

MetadataForm generates:
```
┌─────────────────────────────────────────┐
│ Name: [________________]                 │
│ Status: [backlog ▾]                      │
│ Priority: [-- optional -- ▾]             │
│ Deadline: [📅 Pick date...]              │
│ Estimate: [___]                          │
│ Labels: [chip1] [chip2] [+ add]          │
│                                          │
│                        [Cancel] [Save]   │
└─────────────────────────────────────────┘
```

---

## RelationshipList

Displays an entity's relationships, grouped by relationship type.

```dart
class RelationshipList extends StatelessWidget {
  final List<ResolvedRelationship> relationships;
  final void Function(ResolvedRelationship rel)? onRelationshipTap;
  final void Function()? onAddRelationship;
  final bool canEdit; // show delete buttons on relationships
}
```

Renders:
```
assigned to:
  [person_chip] Robin     [×]
  [person_chip] Sarah     [×]

belongs to:
  [entity_card] CMS Project   [×]

scheduled in:
  [entity_card] Sprint 12      [×]

[+ Add Relationship]
```

Each relationship group uses the `label` from the API response (which already resolves forward/reverse labels). The `[×]` button (visible when `canEdit` is true) deletes the relationship via `DELETE /api/relationships/:id`.

### Add Relationship Dialog

When "+ Add Relationship" is tapped:

1. **Step 1:** Choose relationship type from a dropdown
   - Filter to rel types where this entity's type is a valid source or target
   - Show the appropriate label (forward if source, reverse if target)
2. **Step 2:** Search for the target entity
   - Filter by the valid target type(s) for the chosen rel type
   - Search bar with autocomplete from `GET /api/entities?type=<targetType>&search=<query>`
3. **Submit:** `POST /api/relationships { rel_type_key, source_entity_id, target_entity_id }`

---

## SearchBar

A text input with search icon and debounced callback.

```dart
class SearchBar extends StatelessWidget {
  final String hint;                          // e.g., "Search documents..."
  final void Function(String query) onSearch; // debounced (300ms)
  final String? initialValue;
}
```

---

## FilterBar

A row of dropdown filters. Used on Tasks and Documents screens.

```dart
class FilterBar extends StatelessWidget {
  final List<FilterDefinition> filters;
  final void Function(Map<String, String?> activeFilters) onFiltersChanged;
  final void Function() onClearAll;
}

class FilterDefinition {
  final String key;          // e.g., "priority"
  final String label;        // e.g., "Priority"
  final List<FilterOption> options;  // dropdown items
}

class FilterOption {
  final String value;        // e.g., "high"
  final String label;        // e.g., "High"
}
```

Renders as a horizontal row of dropdowns with a "Clear" button at the end. On mobile, wraps to multiple rows or uses a horizontal scroll.

---

## PaginatedList

A list view with pagination controls.

```dart
class PaginatedList<T> extends StatelessWidget {
  final List<T> items;
  final int total;
  final int page;
  final int perPage;
  final Widget Function(T item) itemBuilder;
  final void Function(int page) onPageChanged;
}
```

Renders:
```
[list of items]

Showing 1-50 of 142        [< Prev]  [Next >]
```

---

## ConfirmDialog

A simple confirmation dialog for destructive actions (delete entity, remove relationship).

```dart
class ConfirmDialog extends StatelessWidget {
  final String title;         // e.g., "Delete Task?"
  final String message;       // e.g., "This will permanently delete 'Implement login' and all its relationships."
  final String confirmLabel;  // e.g., "Delete"
  final Color confirmColor;   // e.g., Colors.red
}
```

Returns `true` if confirmed, `false`/`null` if cancelled.

Usage:
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => ConfirmDialog(
    title: 'Delete Task?',
    message: 'This will permanently delete "${task.name}" and all its relationships.',
    confirmLabel: 'Delete',
    confirmColor: Colors.red,
  ),
);
if (confirmed == true) { ... }
```

---

## ErrorSnackbar

A helper to show error messages at the bottom of the screen.

```dart
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Dismiss', textColor: Colors.white, onPressed: () {}),
    ),
  );
}
```

---

## LoadingOverlay

A semi-transparent overlay with a circular progress indicator. Used during form submissions.

```dart
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
}
```

When `isLoading` is true, renders the child with a grey overlay and centered `CircularProgressIndicator`. When false, just renders the child.

---

## Widget Dependency Map

```
Screens
  ├── KanbanBoard (uses PriorityBadge, PersonChip)
  ├── MetadataForm (standalone, schema-driven)
  ├── RelationshipList (uses PersonChip, EntityCard)
  ├── FilterBar (uses FilterDefinition)
  ├── SearchBar
  ├── PaginatedList
  ├── EntityCard (uses type icon/color from schema)
  ├── StatusBadge
  ├── PriorityBadge
  ├── DocTypeBadge
  ├── PersonChip
  ├── ConfirmDialog
  ├── ErrorSnackbar (function, not widget)
  └── LoadingOverlay
```

All shared widgets live in `lib/widgets/shared/` except the kanban widgets which are in `lib/widgets/kanban/`.
