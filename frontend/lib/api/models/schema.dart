/// Full schema response from GET /api/schema.
class Schema {
  final AppConfig app;
  final List<EntityType> entityTypes;
  final List<RelType> relTypes;
  final List<PermissionRule> permissionRules;

  Schema({
    required this.app,
    required this.entityTypes,
    required this.relTypes,
    required this.permissionRules,
  });

  factory Schema.fromJson(Map<String, dynamic> json) {
    return Schema(
      app: AppConfig.fromJson(json['app'] as Map<String, dynamic>),
      entityTypes: (json['entity_types'] as List)
          .map((e) => EntityType.fromJson(e as Map<String, dynamic>))
          .toList(),
      relTypes: (json['rel_types'] as List)
          .map((r) => RelType.fromJson(r as Map<String, dynamic>))
          .toList(),
      permissionRules: (json['permission_rules'] as List)
          .map((p) => PermissionRule.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AppConfig {
  final String name;
  final String description;
  final String themeColor;
  final String? logoUrl;

  AppConfig({
    required this.name,
    required this.description,
    required this.themeColor,
    this.logoUrl,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      name: json['name'] as String,
      description: json['description'] as String,
      themeColor: json['theme_color'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class EntityType {
  final String key;
  final String label;
  final String plural;
  final String icon;
  final String color;
  final bool hidden;
  final Map<String, dynamic> metadataSchema;
  final UiSchema uiSchema;

  EntityType({
    required this.key,
    required this.label,
    required this.plural,
    required this.icon,
    required this.color,
    required this.hidden,
    required this.metadataSchema,
    required this.uiSchema,
  });

  factory EntityType.fromJson(Map<String, dynamic> json) {
    return EntityType(
      key: json['key'] as String,
      label: json['label'] as String,
      plural: json['plural'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      hidden: json['hidden'] as bool? ?? false,
      metadataSchema:
          json['metadata_schema'] as Map<String, dynamic>? ?? {},
      uiSchema: UiSchema.fromJson(
          json['ui_schema'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Typed accessor for the ui_schema config attached to each entity type.
///
/// Wraps the raw JSON map and provides convenient methods so that widgets
/// don't need to do null-safe map lookups everywhere.
class UiSchema {
  final Map<String, dynamic> _raw;

  const UiSchema._(this._raw);

  factory UiSchema.fromJson(Map<String, dynamic> json) => UiSchema._(json);

  static const empty = UiSchema._({});

  /// Raw map access for forward-compatibility.
  Map<String, dynamic> get raw => _raw;

  // ── Field ordering ──────────────────────────────────────────────────

  /// Ordered list of field keys for forms.
  List<String> get fieldOrder =>
      (_raw['ui:order'] as List?)?.cast<String>() ?? [];

  // ── Per-field properties ────────────────────────────────────────────

  Map<String, dynamic> get _properties =>
      _raw['properties'] as Map<String, dynamic>? ?? {};

  /// Get the UI label override for a field, or null to use the default.
  String? labelFor(String field) {
    final props = _properties[field] as Map<String, dynamic>?;
    return props?['ui:label'] as String?;
  }

  /// Get the widget type hint for a field.
  String? widgetFor(String field) {
    final props = _properties[field] as Map<String, dynamic>?;
    return props?['ui:widget'] as String?;
  }

  /// Get the suffix (e.g., "pts") for a field.
  String? suffixFor(String field) {
    final props = _properties[field] as Map<String, dynamic>?;
    return props?['ui:suffix'] as String?;
  }

  /// Get the color map for a field (enum value → hex color string).
  Map<String, String> colorsFor(String field) {
    final props = _properties[field] as Map<String, dynamic>?;
    final colors = props?['ui:colors'] as Map<String, dynamic>?;
    return colors?.map((k, v) => MapEntry(k, v as String)) ?? {};
  }

  /// Whether this field is marked as a kanban column source.
  bool isKanbanColumn(String field) {
    final props = _properties[field] as Map<String, dynamic>?;
    return props?['ui:kanban_column'] == true;
  }

  /// Find the field key marked as ui:kanban_column, or null.
  String? get kanbanColumnField {
    for (final entry in _properties.entries) {
      final props = entry.value as Map<String, dynamic>?;
      if (props?['ui:kanban_column'] == true) return entry.key;
    }
    return null;
  }

  // ── Card config ─────────────────────────────────────────────────────

  Map<String, dynamic> get _card =>
      _raw['card'] as Map<String, dynamic>? ?? {};

  /// The metadata field used as card title (usually "name").
  String get cardTitle => _card['title'] as String? ?? 'name';

  /// Metadata fields to show on cards.
  List<String> get cardFields =>
      (_card['fields'] as List?)?.cast<String>() ?? [];

  /// Card subtitle field or relationship ref (e.g., "@project.name").
  String? get cardSubtitle => _card['subtitle'] as String?;

  // ── Detail panel config ─────────────────────────────────────────────

  Map<String, dynamic> get _detail =>
      _raw['detail'] as Map<String, dynamic>? ?? {};

  /// Grouped sections for the detail panel.
  List<UiSection> get detailSections {
    final sections = _detail['sections'] as List?;
    if (sections == null) return [];
    return sections
        .cast<Map<String, dynamic>>()
        .map((s) => UiSection(
              label: s['label'] as String? ?? '',
              fields: (s['fields'] as List?)?.cast<String>() ?? [],
            ))
        .toList();
  }

  // ── Filter config ───────────────────────────────────────────────────

  /// Which metadata fields should appear as filter dropdowns.
  List<String> get filters =>
      (_raw['filters'] as List?)?.cast<String>() ?? [];
}

/// A named group of fields for detail panel display.
class UiSection {
  final String label;
  final List<String> fields;

  const UiSection({required this.label, required this.fields});
}

class RelType {
  final String key;
  final String forwardLabel;
  final String reverseLabel;
  final List<String> sourceTypes;
  final List<String> targetTypes;
  final bool symmetric;

  RelType({
    required this.key,
    required this.forwardLabel,
    required this.reverseLabel,
    required this.sourceTypes,
    required this.targetTypes,
    required this.symmetric,
  });

  factory RelType.fromJson(Map<String, dynamic> json) {
    return RelType(
      key: json['key'] as String,
      forwardLabel: json['forward_label'] as String,
      reverseLabel: json['reverse_label'] as String,
      sourceTypes: (json['source_types'] as List).cast<String>(),
      targetTypes: (json['target_types'] as List).cast<String>(),
      symmetric: json['symmetric'] as bool? ?? false,
    );
  }
}

class PermissionRule {
  final String ruleType;
  final String? entityTypeKey;
  final String? relTypeKey;

  PermissionRule({
    required this.ruleType,
    this.entityTypeKey,
    this.relTypeKey,
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      ruleType: json['rule_type'] as String,
      entityTypeKey: json['entity_type_key'] as String?,
      relTypeKey: json['rel_type_key'] as String?,
    );
  }
}
