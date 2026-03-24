import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../widgets/shared/entity_card.dart';

/// Sprints section grouped by temporal status.
class MySprintsSection extends StatelessWidget {
  final List<Entity> sprints;
  final void Function(Entity sprint)? onSprintTap;

  const MySprintsSection({
    super.key,
    required this.sprints,
    this.onSprintTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sprints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No sprints'),
      );
    }

    final now = DateTime.now();
    final current = <Entity>[];
    final upcoming = <Entity>[];
    final completed = <Entity>[];

    for (final sprint in sprints) {
      final endStr = sprint.metadata['end_date'] as String?;
      final startStr = sprint.metadata['start_date'] as String?;
      final end = endStr != null ? DateTime.tryParse(endStr) : null;
      final start = startStr != null ? DateTime.tryParse(startStr) : null;

      if (end != null && end.isBefore(now)) {
        completed.add(sprint);
      } else if (start != null && start.isAfter(now)) {
        upcoming.add(sprint);
      } else {
        current.add(sprint);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child:
              Text('Sprints', style: Theme.of(context).textTheme.titleMedium),
        ),
        if (current.isNotEmpty) ...[
          _groupHeader(context, 'Current'),
          ...current.map((s) => EntityCard(entity: s, onTap: () => onSprintTap?.call(s))),
        ],
        if (upcoming.isNotEmpty) ...[
          _groupHeader(context, 'Upcoming'),
          ...upcoming.map((s) => EntityCard(entity: s, onTap: () => onSprintTap?.call(s))),
        ],
        if (completed.isNotEmpty) ...[
          _groupHeader(context, 'Completed'),
          ...completed.map((s) => EntityCard(entity: s, onTap: () => onSprintTap?.call(s))),
        ],
      ],
    );
  }

  Widget _groupHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
