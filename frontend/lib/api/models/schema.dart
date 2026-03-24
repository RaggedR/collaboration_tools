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

  EntityType({
    required this.key,
    required this.label,
    required this.plural,
    required this.icon,
    required this.color,
    required this.hidden,
    required this.metadataSchema,
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
    );
  }
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
