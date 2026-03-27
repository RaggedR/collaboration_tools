import 'package:flutter/material.dart';
import '../../api/models/entity.dart';

/// Displays relationships grouped by type with clickable entity links.
///
/// Wireframe spec: relationships are clickable links (→) that navigate
/// to the related entity. Uses accent color for link text.
/// Each group is collapsible with a compact chevron + count badge.
class RelationshipList extends StatefulWidget {
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
  State<RelationshipList> createState() => _RelationshipListState();
}

class _RelationshipListState extends State<RelationshipList> {
  final _collapsedSections = <String>{};

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ResolvedRelationship>>{};
    for (final rel in widget.relationships) {
      (grouped[rel.label] ??= []).add(rel);
    }

    if (grouped.isEmpty && widget.readOnly) {
      return const SizedBox.shrink();
    }

    final accentColor = Theme.of(context).colorScheme.primary;
    final mutedColor = Theme.of(context)
        .colorScheme
        .onSurfaceVariant
        .withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...grouped.entries.expand((entry) {
          final isCollapsed = _collapsedSections.contains(entry.key);
          return [
            // Tappable section header with chevron + count
            InkWell(
              onTap: () => setState(() {
                if (isCollapsed) {
                  _collapsedSections.remove(entry.key);
                } else {
                  _collapsedSections.add(entry.key);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                child: Row(
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.value.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: mutedColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more,
                          size: 14, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
            // Related entities (hidden when collapsed)
            if (!isCollapsed)
              ...entry.value.map((rel) => _RelationshipItem(
                    rel: rel,
                    accentColor: accentColor,
                    onTap: widget.onEntityTap != null
                        ? () => widget.onEntityTap!(rel.relatedEntity)
                        : null,
                    onDelete: !widget.readOnly && widget.onDelete != null
                        ? () => widget.onDelete!(rel)
                        : null,
                  )),
          ];
        }),
        if (!widget.readOnly && widget.onAdd != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add relationship'),
            ),
          ),
      ],
    );
  }
}

/// A single relationship item — styled as a clickable link with → arrow.
class _RelationshipItem extends StatelessWidget {
  final ResolvedRelationship rel;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _RelationshipItem({
    required this.rel,
    required this.accentColor,
    this.onTap,
    this.onDelete,
  });

  static const _typeIcons = {
    'task': Icons.check_circle_outline,
    'project': Icons.folder_outlined,
    'sprint': Icons.timer_outlined,
    'document': Icons.description_outlined,
    'person': Icons.person_outline,
    'workspace': Icons.business_outlined,
  };

  static const _typeColors = {
    'task': Color(0xFF10B981),
    'project': Color(0xFF3B82F6),
    'sprint': Color(0xFF8B5CF6),
    'document': Color(0xFFF59E0B),
    'person': Color(0xFFEC4899),
    'workspace': Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[rel.relatedEntity.type] ?? Icons.circle_outlined;
    final typeColor =
        _typeColors[rel.relatedEntity.type] ?? const Color(0xFF6B7280);
    final isTappable = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: typeColor.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rel.relatedEntity.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isTappable ? accentColor : null,
                  decoration:
                      isTappable ? TextDecoration.none : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
              )
            else if (isTappable)
              Icon(Icons.arrow_forward,
                  size: 14,
                  color: accentColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
