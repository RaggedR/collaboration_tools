import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../shared/priority_badge.dart';
import '../shared/status_badge.dart';

/// A single task card in a kanban column.
///
/// When [uiSchema] is provided, card.fields determines which metadata
/// fields are shown. Falls back to hardcoded priority + deadline.
class KanbanCard extends StatelessWidget {
  final Entity task;
  final VoidCallback? onTap;
  final bool isDraggable;
  final UiSchema? uiSchema;

  const KanbanCard({
    super.key,
    required this.task,
    this.onTap,
    this.isDraggable = true,
    this.uiSchema,
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              _buildCardFields(context),
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

  /// Builds the metadata row on the card.
  ///
  /// If uiSchema specifies card.fields, renders those fields.
  /// Otherwise falls back to the original priority + deadline layout.
  Widget _buildCardFields(BuildContext context) {
    final fields = uiSchema?.cardFields;
    if (fields == null || fields.isEmpty) {
      return _buildDefaultFields(context);
    }

    final widgets = <Widget>[];
    for (final field in fields) {
      final value = task.metadata[field];
      if (value == null) continue;

      final fieldWidget = _buildFieldWidget(context, field, value);
      if (fieldWidget != null) widgets.add(fieldWidget);
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

  Widget _buildDefaultFields(BuildContext context) {
    return Row(
      children: [
        if (task.metadata['priority'] != null)
          PriorityBadge(priority: task.metadata['priority'] as String),
        const Spacer(),
        if (task.metadata['deadline'] != null)
          Text(
            task.metadata['deadline'] as String,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget? _buildFieldWidget(BuildContext context, String field, dynamic value) {
    final colors = uiSchema?.colorsFor(field) ?? {};

    if (field == 'priority') {
      return PriorityBadge(
        priority: value as String,
        colorOverrides: colors,
      );
    }
    if (field == 'status') {
      return StatusBadge(
        status: value as String,
        colorOverrides: colors,
      );
    }

    // Date fields — show as plain text
    final widget = uiSchema?.widgetFor(field);
    if (widget == 'date' || field.contains('date') || field == 'deadline') {
      return Text(
        value as String,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    // Default: show as text
    return Text(
      '$value',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
