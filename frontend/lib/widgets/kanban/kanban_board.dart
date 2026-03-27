import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../shared/priority_badge.dart';

/// Kanban board using drag_and_drop_lists package.
///
/// Manages its own local copy of task lists so the package's internal
/// drag state doesn't conflict with external rebuilds. Syncs back to
/// the parent via onStatusChange for API persistence.
class KanbanBoard extends StatefulWidget {
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
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  // Local mutable copy of task lists — package mutates these on drag
  late Map<String, List<Entity>> _localColumns;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(KanbanBoard old) {
    super.didUpdateWidget(old);
    // Only sync from parent if the data actually changed externally
    // (not as a result of our own drag operation)
    if (!_sameColumns(widget.columns, old.columns)) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _localColumns = {
      for (final status in widget.columnOrder)
        status: List<Entity>.from(widget.columns[status] ?? []),
    };
  }

  bool _sameColumns(
      Map<String, List<Entity>> a, Map<String, List<Entity>> b) {
    for (final key in a.keys) {
      final aList = a[key] ?? [];
      final bList = b[key] ?? [];
      if (aList.length != bList.length) return false;
      for (var i = 0; i < aList.length; i++) {
        if (aList[i].id != bList[i].id) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DragAndDropLists(
      children: widget.columnOrder.map((status) {
        final tasks = _localColumns[status] ?? [];
        final color = widget.columnColors[status];
        final label = widget.columnLabels[status] ?? status;

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
                onTap: widget.onTaskTap != null
                    ? () => widget.onTaskTap!(task)
                    : null,
                child: Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (!widget.readOnly)
                              _buildMoveMenu(
                                  context, task, status),
                          ],
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
          canDrag: !widget.readOnly,
        );
      }).toList(),
      onItemReorder:
          (oldItemIndex, oldListIndex, newItemIndex, newListIndex) {
        final fromStatus = widget.columnOrder[oldListIndex];
        final toStatus = widget.columnOrder[newListIndex];
        print('[KANBAN DROP] $fromStatus[$oldItemIndex] -> $toStatus[$newItemIndex]');

        setState(() {
          final movedTask =
              _localColumns[fromStatus]!.removeAt(oldItemIndex);
          _localColumns[toStatus]!.insert(newItemIndex, movedTask);
          print('[KANBAN DROP] moved "${movedTask.name}" — ${fromStatus}(${_localColumns[fromStatus]!.length}) ${toStatus}(${_localColumns[toStatus]!.length})');
        });

        // Fire API call (don't await — local state is already updated)
        if (fromStatus != toStatus) {
          final task = _localColumns[toStatus]![newItemIndex];
          widget.onStatusChange?.call(task.id, fromStatus, toStatus);
        }
      },
      onListReorder: (a, b) {},
      axis: Axis.horizontal,
      listWidth: 280,
      listDraggingWidth: 280,
      listPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      listDragOnLongPress: true,
      listDecoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8FAFC),
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
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildMoveMenu(
      BuildContext context, Entity task, String currentStatus) {
    final otherStatuses = widget.columnOrder
        .where((s) => s != currentStatus)
        .toList();

    return PopupMenuButton<String>(
      icon: Icon(Icons.arrow_forward,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
      tooltip: 'Move to...',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (context) => otherStatuses.map((status) {
        final label = widget.columnLabels[status] ?? status;
        final color = widget.columnColors[status];
        return PopupMenuItem<String>(
          value: status,
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
              Text(label),
            ],
          ),
        );
      }).toList(),
      onSelected: (toStatus) {
        setState(() {
          final fromList = _localColumns[currentStatus]!;
          final idx = fromList.indexWhere((t) => t.id == task.id);
          if (idx >= 0) {
            final moved = fromList.removeAt(idx);
            _localColumns[toStatus]!.add(moved);
          }
        });
        widget.onStatusChange?.call(task.id, currentStatus, toStatus);
      },
    );
  }

  Widget _buildCardFields(BuildContext context, Entity task) {
    final fields = widget.uiSchema?.cardFields;
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
          colorOverrides: widget.uiSchema?.colorsFor(field) ?? {},
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
