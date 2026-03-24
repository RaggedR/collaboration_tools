import 'package:flutter/material.dart';
import '../../api/models/schema.dart';
import 'status_badge.dart';
import 'priority_badge.dart';
import 'doc_type_badge.dart';

/// Renders metadata fields grouped by sections from ui_schema.
///
/// When ui_schema has detail.sections, fields are grouped under section
/// headers. Without ui_schema, all fields are displayed flat.
class SchemaFieldsDisplay extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final UiSchema uiSchema;
  final Map<String, dynamic> metadataSchema;

  const SchemaFieldsDisplay({
    super.key,
    required this.metadata,
    required this.uiSchema,
    required this.metadataSchema,
  });

  @override
  Widget build(BuildContext context) {
    final sections = uiSchema.detailSections;

    if (sections.isEmpty) {
      // No sections configured — render all fields flat
      return _buildFlatFields(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          _buildSection(context, section),
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, UiSection section) {
    // Only show section if at least one field has a value
    final hasValues = section.fields.any((f) => metadata[f] != null);
    if (!hasValues) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            section.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        ...section.fields.map((field) => _buildFieldRow(context, field)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildFieldRow(BuildContext context, String field) {
    final value = metadata[field];
    if (value == null) return const SizedBox.shrink();

    final label = uiSchema.labelFor(field) ?? _humanize(field);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: _buildFieldValue(context, field, value)),
        ],
      ),
    );
  }

  Widget _buildFieldValue(BuildContext context, String field, dynamic value) {
    final colors = uiSchema.colorsFor(field);
    final widget = uiSchema.widgetFor(field);
    final suffix = uiSchema.suffixFor(field);

    // Render enum fields with badges when colors are available
    if (value is String && colors.isNotEmpty) {
      // Detect the field type for appropriate badge
      if (field == 'status' || uiSchema.isKanbanColumn(field)) {
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(status: value, colorOverrides: colors),
        );
      }
      if (field == 'priority') {
        return Align(
          alignment: Alignment.centerLeft,
          child: PriorityBadge(priority: value, colorOverrides: colors),
        );
      }
      if (field == 'doc_type') {
        return Align(
          alignment: Alignment.centerLeft,
          child: DocTypeBadge(docType: value, colorOverrides: colors),
        );
      }
      // Generic colored chip for other enum fields
      final hex = colors[value];
      final color = hex != null ? StatusBadge.parseHex(hex) : null;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: color != null
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                )
              : null,
          child: Text(
            _humanize(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      );
    }

    // Array → comma-separated
    if (value is List) {
      return Text(
        value.join(', '),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    // URL → tappable link style
    if (widget == 'url' && value is String) {
      return Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
      );
    }

    // Number with suffix
    if (suffix != null) {
      return Text(
        '$value $suffix',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    // Default: plain text
    return Text(
      '$value',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildFlatFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metadata.entries
          .where((e) => e.value != null)
          .map((e) => _buildFieldRow(context, e.key))
          .toList(),
    );
  }

  static String _humanize(String s) {
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
