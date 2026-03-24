import 'package:flutter/material.dart';
import '../../api/models/entity.dart';

/// Displays relationships grouped by type with add/delete controls.
class RelationshipList extends StatelessWidget {
  final List<ResolvedRelationship> relationships;
  final void Function(ResolvedRelationship rel)? onDelete;
  final VoidCallback? onAdd;
  final void Function(RelatedEntity entity)? onEntityTap;
  final bool readOnly;

  const RelationshipList({
    super.key,
    required this.relationships,
    this.onDelete,
    this.onAdd,
    this.onEntityTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ResolvedRelationship>>{};
    for (final rel in relationships) {
      (grouped[rel.label] ??= []).add(rel);
    }

    if (grouped.isEmpty && readOnly) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No relationships'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              ...entry.value.map((rel) => ListTile(
                    dense: true,
                    leading: Icon(
                      _iconForType(rel.relatedEntity.type),
                      size: 20,
                    ),
                    title: Text(rel.relatedEntity.name),
                    trailing: !readOnly && onDelete != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onDelete!(rel),
                          )
                        : null,
                    onTap: onEntityTap != null
                        ? () => onEntityTap!(rel.relatedEntity)
                        : null,
                  )),
            ]),
        if (!readOnly && onAdd != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add relationship'),
            ),
          ),
      ],
    );
  }

  static IconData _iconForType(String type) {
    const icons = {
      'task': Icons.check_circle,
      'project': Icons.folder,
      'sprint': Icons.timer,
      'document': Icons.description,
      'person': Icons.person,
      'workspace': Icons.business,
    };
    return icons[type] ?? Icons.circle;
  }
}
