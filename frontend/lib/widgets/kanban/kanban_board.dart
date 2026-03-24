import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import 'kanban_column.dart';

/// Reusable kanban board widget.
///
/// Shared between My Page (filtered to one person) and Tasks screen (all tasks).
/// Stateless regarding data — receives tasks and callbacks from parent.
class KanbanBoard extends StatelessWidget {
  /// Tasks grouped by status column.
  final Map<String, List<Entity>> columns;

  /// Column order (e.g., ["backlog", "todo", "in_progress", "review", "done"]).
  final List<String> columnOrder;

  /// Column display names (e.g., {"in_progress": "In Progress"}).
  final Map<String, String> columnLabels;

  /// Called when a card is dragged to a new column.
  final void Function(String taskId, String fromStatus, String toStatus)?
      onStatusChange;

  /// Called when a card is tapped.
  final void Function(Entity task)? onTaskTap;

  /// If true, disables drag-and-drop.
  final bool readOnly;

  /// Columns to hide by default.
  final List<String> collapsedColumns;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.columnOrder,
    required this.columnLabels,
    this.onStatusChange,
    this.onTaskTap,
    this.readOnly = false,
    this.collapsedColumns = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columnOrder.map((status) {
          final tasks = columns[status] ?? [];
          final isCollapsed = collapsedColumns.contains(status);
          return SizedBox(
            width: 280,
            child: KanbanColumn(
              status: status,
              label: columnLabels[status] ?? status,
              tasks: tasks,
              isCollapsed: isCollapsed,
              onTaskTap: onTaskTap,
              acceptsDrop: !readOnly,
              onDrop: !readOnly
                  ? (taskId) => onStatusChange?.call(taskId, '', status)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
