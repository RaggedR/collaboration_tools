class PermissionRule {
  final String ruleType;
  final String? entityTypeKey;
  final String? relTypeKey;

  PermissionRule({
    required this.ruleType,
    this.entityTypeKey,
    this.relTypeKey,
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) => PermissionRule(
        ruleType: json['rule_type'] as String,
        entityTypeKey: json['entity_type_key'] as String?,
        relTypeKey: json['rel_type_key'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'rule_type': ruleType,
        if (entityTypeKey != null) 'entity_type_key': entityTypeKey,
        if (relTypeKey != null) 'rel_type_key': relTypeKey,
      };
}
