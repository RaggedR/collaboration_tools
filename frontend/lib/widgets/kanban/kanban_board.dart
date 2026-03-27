import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../shared/priority_badge.dart';

/// Kanban board with custom pointer-based drag-and-drop.
///
/// Uses GestureDetector + Overlay + GlobalKey hit-testing instead of
/// Flutter's DragTarget, which breaks inside horizontally scrollable
/// containers on Flutter Web (DragTarget.hitTest walks top-down and
/// fails to account for scroll transforms; RenderBox.globalToLocal
/// walks bottom-up and handles them correctly).
///
/// Gesture strategy:
///   - Tap → opens detail panel
///   - Long press → initiates drag (standard mobile pattern)
///   - Horizontal scroll → wins if user moves before long-press threshold
///
/// Manages its own local copy of task lists so drag state doesn't
/// conflict with external rebuilds. Syncs back to the parent via
/// onStatusChange for API persistence.
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
  // Local mutable copy of task lists
  late Map<String, List<Entity>> _localColumns;

  // Column hit-testing keys — persist across rebuilds
  final Map<String, GlobalKey> _columnKeys = {};

  // Drag state
  Entity? _draggedTask;
  String? _dragSourceStatus;
  String? _hoveredStatus;
  OverlayEntry? _dragOverlay;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(KanbanBoard old) {
    super.didUpdateWidget(old);
    if (!_sameColumns(widget.columns, old.columns)) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _localColumns = {
      for (final status in widget.columnOrder)
        status: List<Entity>.from(widget.columns[status] ?? []),
    };
    for (final status in widget.columnOrder) {
      _columnKeys.putIfAbsent(status, () => GlobalKey());
    }
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
  void dispose() {
    _cancelDrag();
    super.dispose();
  }

  // ── Drag logic ──────────────────────────────────────────────────────

  void _onLongPressStart(
      Entity task, String status, LongPressStartDetails details) {
    if (widget.readOnly) return;
    setState(() {
      _draggedTask = task;
      _dragSourceStatus = status;
      _dragOffset = details.globalPosition;
    });
    _showOverlay();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggedTask == null) return;
    _dragOffset = details.globalPosition;
    _dragOverlay?.markNeedsBuild();

    final hovered = _findColumnAtPosition(details.globalPosition);
    if (hovered != _hoveredStatus) {
      setState(() => _hoveredStatus = hovered);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_draggedTask == null) return;
    final targetStatus = _findColumnAtPosition(details.globalPosition);
    final task = _draggedTask!;
    final fromStatus = _dragSourceStatus!;

    _cancelDrag();

    if (targetStatus != null && targetStatus != fromStatus) {
      setState(() {
        final fromList = _localColumns[fromStatus]!;
        final idx = fromList.indexWhere((t) => t.id == task.id);
        if (idx >= 0) {
          final moved = fromList.removeAt(idx);
          _localColumns[targetStatus]!.add(moved);
        }
      });
      widget.onStatusChange?.call(task.id, fromStatus, targetStatus);
    }
  }

  void _cancelDrag() {
    _dragOverlay?.remove();
    _dragOverlay = null;
    if (_draggedTask != null || _hoveredStatus != null) {
      setState(() {
        _draggedTask = null;
        _dragSourceStatus = null;
        _hoveredStatus = null;
      });
    }
  }

  void _showOverlay() {
    _dragOverlay?.remove();
    _dragOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _dragOffset.dx - 120,
          top: _dragOffset.dy - 40,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 240,
                child: _buildCardContent(context, _draggedTask!),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_dragOverlay!);
  }

  /// Determine which column the pointer is over using globalToLocal.
  ///
  /// globalToLocal walks bottom-up from each column's RenderBox, correctly
  /// accounting for scroll transforms — unlike DragTarget.hitTest which
  /// walks top-down and breaks with horizontal scroll.
  String? _findColumnAtPosition(Offset globalPosition) {
    for (final entry in _columnKeys.entries) {
      final box =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final local = box.globalToLocal(globalPosition);
      if (local.dx >= 0 &&
          local.dx <= box.size.width &&
          local.dy >= 0 &&
          local.dy <= box.size.height) {
        return entry.key;
      }
    }
    return null;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.columnOrder
                .where((s) => !widget.collapsedColumns.contains(s))
                .map((status) {
              final tasks = _localColumns[status] ?? [];
              final color = widget.columnColors[status];
              final label = widget.columnLabels[status] ?? status;
              final isHovered =
                  _hoveredStatus == status && _dragSourceStatus != status;

              return SizedBox(
                height: constraints.maxHeight,
                child: Container(
                  key: _columnKeys[status],
                  width: 280,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHovered
                          ? Theme.of(context).colorScheme.primary
                          : (isDark
                              ? Colors.white10
                              : const Color(0xFFE2E8F0)),
                      width: isHovered ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Column header
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                          border: color != null
                              ? Border(
                                  top: BorderSide(color: color, width: 3))
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall),
                            const SizedBox(width: 8),
                            Text('${tasks.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    )),
                          ],
                        ),
                      ),

                      // Scrollable card list
                      Expanded(
                        child: tasks.isEmpty
                            ? Center(
                                child: Text('Drop here',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: tasks.map((task) {
                                    final isDragging =
                                        _draggedTask?.id == task.id;
                                    return Opacity(
                                      opacity: isDragging ? 0.3 : 1.0,
                                      child: GestureDetector(
                                        onTap: widget.onTaskTap != null
                                            ? () =>
                                                widget.onTaskTap!(task)
                                            : null,
                                        onLongPressStart: (details) =>
                                            _onLongPressStart(
                                                task, status, details),
                                        onLongPressMoveUpdate:
                                            _onLongPressMoveUpdate,
                                        onLongPressEnd: _onLongPressEnd,
                                        onLongPressCancel: _cancelDrag,
                                        child: Card(
                                          margin: const EdgeInsets
                                              .symmetric(
                                              horizontal: 6,
                                              vertical: 3),
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        task.name,
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: Theme.of(
                                                                context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                      ),
                                                    ),
                                                    if (!widget.readOnly)
                                                      _buildMoveMenu(
                                                          context,
                                                          task,
                                                          status),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                _buildCardFields(
                                                    context, task),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Card content used in the drag overlay.
  Widget _buildCardContent(BuildContext context, Entity task) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
