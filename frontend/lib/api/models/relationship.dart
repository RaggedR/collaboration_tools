/// A raw relationship (from the list endpoint).
class Relationship {
  final String id;
  final String relTypeKey;
  final String sourceEntityId;
  final String targetEntityId;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;

  Relationship({
    required this.id,
    required this.relTypeKey,
    required this.sourceEntityId,
    required this.targetEntityId,
    required this.metadata,
    this.createdBy,
    required this.createdAt,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'] as String,
      relTypeKey: json['rel_type_key'] as String,
      sourceEntityId: json['source_entity_id'] as String,
      targetEntityId: json['target_entity_id'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rel_type_key': relTypeKey,
        'source_entity_id': sourceEntityId,
        'target_entity_id': targetEntityId,
        'metadata': metadata,
        'created_by': createdBy,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
