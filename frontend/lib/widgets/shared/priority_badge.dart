import 'package:flutter/material.dart';
import 'status_badge.dart';

/// Displays task priority as a coloured chip.
///
/// When [colorOverrides] is provided (from ui_schema), those colors take
/// precedence over the built-in defaults.
class PriorityBadge extends StatelessWidget {
  final String priority;

  /// Optional color map from ui_schema (priority value -> hex color string).
  final Map<String, String> colorOverrides;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.colorOverrides = const {},
  });

  static const _defaultColors = {
    'low': Color(0xFF9CA3AF),
    'medium': Color(0xFF3B82F6),
    'high': Color(0xFFF97316),
    'urgent': Color(0xFFEF4444),
  };

  static const _icons = {
    'low': Icons.arrow_downward,
    'medium': Icons.remove,
    'high': Icons.arrow_upward,
    'urgent': Icons.priority_high,
  };

  Color get color {
    final hex = colorOverrides[priority];
    if (hex != null) return StatusBadge.parseHex(hex);
    return _defaultColors[priority] ?? const Color(0xFF9CA3AF);
  }

  IconData get icon => _icons[priority] ?? Icons.help_outline;

  String get label {
    if (priority.isEmpty) return priority;
    return '${priority[0].toUpperCase()}${priority.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
