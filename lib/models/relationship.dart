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
