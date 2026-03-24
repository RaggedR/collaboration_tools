import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import 'kanban_card.dart';

/// A single column in the kanban board.
class KanbanColumn extends StatelessWidget {
  final String status;
  final String label;
  final List<Entity> tasks;
  final bool isCollapsed;
  final void Function(Entity task)? onTaskTap;
  final bool acceptsDrop;
  final void Function(String taskId)? onDrop;

  /// Optional accent color for the column header (from ui_schema).
  final Color? headerColor;

  /// Optional UI schema passed through to cards.
  final UiSchema? uiSchema;

  const KanbanColumn({
    super.key,
    required this.status,
    required this.label,
    required this.tasks,
    this.isCollapsed = false,
    this.onTaskTap,
    this.acceptsDrop = true,
    this.onDrop,
    this.headerColor,
    this.uiSchema,
  });

  @override
  Widget build(BuildContext context) {
    final content = Card(
      margin: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with optional color accent
          Container(
            padding: const EdgeInsets.all(8),
            decoration: headerColor != null
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: headerColor!, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: [
                if (headerColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: headerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                Text(
                  '${tasks.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cards
          if (!isCollapsed)
            ...tasks.map((task) => KanbanCard(
                  task: task,
                  uiSchema: uiSchema,
                  onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                  isDraggable: acceptsDrop,
                )),

          // Empty drop zone when column has no tasks
          if (!isCollapsed && tasks.isEmpty && acceptsDrop)
            const SizedBox(height: 60),
        ],
      ),
    );

    if (!acceptsDrop) return content;

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop?.call(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: content,
        );
      },
    );
  }
}
