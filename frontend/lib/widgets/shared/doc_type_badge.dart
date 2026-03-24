import 'package:flutter/material.dart';
import 'status_badge.dart';

/// Displays document type as a coloured chip.
///
/// When [colorOverrides] is provided (from ui_schema), those colors take
/// precedence over the built-in defaults.
class DocTypeBadge extends StatelessWidget {
  final String docType;

  /// Optional color map from ui_schema (doc_type value -> hex color string).
  final Map<String, String> colorOverrides;

  const DocTypeBadge({
    super.key,
    required this.docType,
    this.colorOverrides = const {},
  });

  static const _defaultColors = {
    'spec': Color(0xFF3B82F6),
    'note': Color(0xFF10B981),
    'report': Color(0xFFF59E0B),
    'reference': Color(0xFF8B5CF6),
  };

  static const _icons = {
    'spec': Icons.article,
    'note': Icons.sticky_note_2,
    'report': Icons.assessment,
    'reference': Icons.menu_book,
  };

  Color get color {
    final hex = colorOverrides[docType];
    if (hex != null) return StatusBadge.parseHex(hex);
    return _defaultColors[docType] ?? const Color(0xFF9CA3AF);
  }

  IconData get icon => _icons[docType] ?? Icons.description;

  String get label {
    if (docType.isEmpty) return docType;
    return '${docType[0].toUpperCase()}${docType.substring(1)}';
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
