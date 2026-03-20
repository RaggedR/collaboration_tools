class EntityType {
  final String key;
  final String label;
  final String plural;
  final String? icon;
  final String color;
  final bool hidden;
  final Map<String, dynamic>? metadataSchema;
  final int sortOrder;

  EntityType({
    required this.key,
    required this.label,
    required this.plural,
    this.icon,
    this.color = '#6b7280',
    this.hidden = false,
    this.metadataSchema,
    this.sortOrder = 0,
  });

  factory EntityType.fromJson(Map<String, dynamic> json) => EntityType(
        key: json['key'] as String,
        label: json['label'] as String,
        plural: json['plural'] as String,
        icon: json['icon'] as String?,
        color: (json['color'] as String?) ?? '#6b7280',
        hidden: (json['hidden'] as bool?) ?? false,
        metadataSchema: json['metadata_schema'] as Map<String, dynamic>?,
        sortOrder: (json['sort_order'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'plural': plural,
        'icon': icon,
        'color': color,
        'hidden': hidden,
        if (metadataSchema != null) 'metadata_schema': metadataSchema,
        'sort_order': sortOrder,
      };
}
