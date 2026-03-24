import 'package:flutter/material.dart';

/// Displays task status as a coloured chip.
///
/// When [colorOverrides] is provided (from ui_schema), those colors take
/// precedence over the built-in defaults.
class StatusBadge extends StatelessWidget {
  final String status;

  /// Optional color map from ui_schema (status value -> hex color string).
  final Map<String, String> colorOverrides;

  const StatusBadge({
    super.key,
    required this.status,
    this.colorOverrides = const {},
  });

  static const _defaultColors = {
    'backlog': Color(0xFF9CA3AF),
    'todo': Color(0xFF3B82F6),
    'in_progress': Color(0xFFF59E0B),
    'review': Color(0xFF8B5CF6),
    'done': Color(0xFF10B981),
    'archived': Color(0xFF6B7280),
  };

  static const _icons = {
    'backlog': Icons.inbox,
    'todo': Icons.radio_button_unchecked,
    'in_progress': Icons.play_circle_outline,
    'review': Icons.rate_review_outlined,
    'done': Icons.check_circle,
    'archived': Icons.archive_outlined,
  };

  Color get color {
    final hex = colorOverrides[status];
    if (hex != null) return parseHex(hex);
    return _defaultColors[status] ?? const Color(0xFF9CA3AF);
  }

  IconData get icon => _icons[status] ?? Icons.circle;

  /// Parses a hex color string (e.g., "#ef4444") into a Color.
  static Color parseHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(0xFF000000 | int.parse(cleaned, radix: 16));
  }

  String get label => status
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

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
