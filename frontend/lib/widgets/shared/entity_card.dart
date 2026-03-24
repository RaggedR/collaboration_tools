import 'package:flutter/material.dart';
import '../../api/models/entity.dart';

/// A generic card for displaying any entity in a list context.
class EntityCard extends StatelessWidget {
  final Entity entity;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? subtitle;

  const EntityCard({
    super.key,
    required this.entity,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  static const _typeColors = {
    'task': Color(0xFF10B981),
    'project': Color(0xFF3B82F6),
    'sprint': Color(0xFF8B5CF6),
    'document': Color(0xFFF59E0B),
    'person': Color(0xFFEC4899),
    'workspace': Color(0xFF6B7280),
  };

  static const _typeIcons = {
    'task': Icons.check_circle,
    'project': Icons.folder,
    'sprint': Icons.timer,
    'document': Icons.description,
    'person': Icons.person,
    'workspace': Icons.business,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[entity.type] ?? const Color(0xFF6B7280);
    final icon = _typeIcons[entity.type] ?? Icons.circle;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(entity.name),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
