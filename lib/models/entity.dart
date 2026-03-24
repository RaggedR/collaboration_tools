class Entity {
  final String id;
  final String type;
  final String name;
  final String? body;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Entity({
    required this.id,
    required this.type,
    required this.name,
    this.body,
    required this.metadata,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (body != null) 'body': body,
        'metadata': metadata,
        'created_by': createdBy,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class RelatedEntity {
  final String id;
  final String type;
  final String name;

  RelatedEntity({
    required this.id,
    required this.type,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
      };
}

class ResolvedRelationship {
  final String id;
  final String relTypeKey;
  final String direction;
  final String label;
  final RelatedEntity relatedEntity;
  final Map<String, dynamic> metadata;

  ResolvedRelationship({
    required this.id,
    required this.relTypeKey,
    required this.direction,
    required this.label,
    required this.relatedEntity,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rel_type_key': relTypeKey,
        'direction': direction,
        'label': label,
        'related_entity': relatedEntity.toJson(),
        'metadata': metadata,
      };
}

class EntityWithRelationships {
  final Entity entity;
  final List<ResolvedRelationship> relationships;

  EntityWithRelationships({
    required this.entity,
    required this.relationships,
  });
}

class PaginatedEntities {
  final List<Entity> entities;
  final int total;

  PaginatedEntities({required this.entities, required this.total});
}
