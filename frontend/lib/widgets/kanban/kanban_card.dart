import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../shared/priority_badge.dart';

/// A single task card in a kanban column.
class KanbanCard extends StatelessWidget {
  final Entity task;
  final VoidCallback? onTap;
  final bool isDraggable;

  const KanbanCard({
    super.key,
    required this.task,
    this.onTap,
    this.isDraggable = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (task.metadata['priority'] != null)
                    PriorityBadge(
                        priority: task.metadata['priority'] as String),
                  const Spacer(),
                  if (task.metadata['deadline'] != null)
                    Text(
                      task.metadata['deadline'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!isDraggable) return card;

    return Draggable<String>(
      data: task.id,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 250, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}
