import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../shared/priority_badge.dart';

/// Kanban board using drag_and_drop_lists package.
///
/// Each status column is a DragAndDropList (horizontal axis).
/// Cards are DragAndDropItems that can be moved between columns.
class KanbanBoard extends StatelessWidget {
  final Map<String, List<Entity>> columns;
  final List<String> columnOrder;
  final Map<String, String> columnLabels;
  final Map<String, Color> columnColors;
  final UiSchema? uiSchema;
  final void Function(String taskId, String fromStatus, String toStatus)?
      onStatusChange;
  final void Function(Entity task)? onTaskTap;
  final bool readOnly;
  final List<String> collapsedColumns;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.columnOrder,
    required this.columnLabels,
    this.columnColors = const {},
    this.uiSchema,
    this.onStatusChange,
    this.onTaskTap,
    this.readOnly = false,
    this.collapsedColumns = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DragAndDropLists(
      children: columnOrder.map((status) {
        final tasks = columns[status] ?? [];
        final color = columnColors[status];
        final label = columnLabels[status] ?? status;

        return DragAndDropList(
          header: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: color != null
                  ? Border(top: BorderSide(color: color, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Text('${tasks.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        )),
              ],
            ),
          ),
          children: tasks.map((task) {
            return DragAndDropItem(
              child: GestureDetector(
                onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _buildCardFields(context, task),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          canDrag: !readOnly,
        );
      }).toList(),
      onItemReorder: (oldItemIndex, oldListIndex, newItemIndex, newListIndex) {
        if (oldListIndex == newListIndex) return; // same column, ignore
        final fromStatus = columnOrder[oldListIndex];
        final toStatus = columnOrder[newListIndex];
        final tasks = columns[fromStatus];
        if (tasks != null && oldItemIndex < tasks.length) {
          final task = tasks[oldItemIndex];
          onStatusChange?.call(task.id, fromStatus, toStatus);
        }
      },
      onListReorder: (a, b) {}, // don't allow column reordering
      axis: Axis.horizontal,
      listWidth: 280,
      listDraggingWidth: 280,
      listPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      listDragOnLongPress: true, // columns can't be reordered by short press
      listDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      itemDecorationWhileDragging: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      contentsWhenEmpty: Container(
        padding: const EdgeInsets.all(20),
        child: Text('Drop here',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildCardFields(BuildContext context, Entity task) {
    final fields = uiSchema?.cardFields;
    if (fields == null || fields.isEmpty) {
      return Row(
        children: [
          if (task.metadata['priority'] != null)
            PriorityBadge(
                priority: task.metadata['priority'] as String),
          const Spacer(),
          if (task.metadata['deadline'] != null)
            Text(task.metadata['deadline'] as String,
                style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    final widgets = <Widget>[];
    for (final field in fields) {
      final value = task.metadata[field];
      if (value == null) continue;
      if (field == 'priority') {
        widgets.add(PriorityBadge(
          priority: value as String,
          colorOverrides: uiSchema?.colorsFor(field) ?? {},
        ));
      } else {
        widgets.add(Text('$value',
            style: Theme.of(context).textTheme.bodySmall));
      }
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        ...widgets.take(1),
        const Spacer(),
        ...widgets.skip(1),
      ],
    );
  }
}
