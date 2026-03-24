/// An entity in the system (task, sprint, document, person, project, workspace).
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

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      body: json['body'] as String?,
      metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : {},
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

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

/// An entity reference within a relationship.
class RelatedEntity {
  final String id;
  final String type;
  final String name;

  RelatedEntity({
    required this.id,
    required this.type,
    required this.name,
  });

  factory RelatedEntity.fromJson(Map<String, dynamic> json) {
    return RelatedEntity(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'name': name};
}

/// A relationship resolved with direction and label.
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

  factory ResolvedRelationship.fromJson(Map<String, dynamic> json) {
    return ResolvedRelationship(
      id: json['id'] as String,
      relTypeKey: json['rel_type_key'] as String,
      direction: json['direction'] as String,
      label: json['label'] as String,
      relatedEntity: RelatedEntity.fromJson(
          Map<String, dynamic>.from(json['related_entity'] as Map)),
      metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rel_type_key': relTypeKey,
        'direction': direction,
        'label': label,
        'related_entity': relatedEntity.toJson(),
        'metadata': metadata,
      };
}

/// An entity with its resolved relationships.
class EntityWithRelationships {
  final Entity entity;
  final List<ResolvedRelationship> relationships;

  EntityWithRelationships({
    required this.entity,
    required this.relationships,
  });

  factory EntityWithRelationships.fromJson(Map<String, dynamic> json) {
    return EntityWithRelationships(
      entity: Entity.fromJson(
          Map<String, dynamic>.from(json['entity'] as Map)),
      relationships: (json['relationships'] as List)
          .map((r) => ResolvedRelationship.fromJson(
              Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

/// Paginated entity list response.
class PaginatedEntities {
  final List<Entity> entities;
  final int total;
  final int page;
  final int perPage;

  PaginatedEntities({
    required this.entities,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory PaginatedEntities.fromJson(Map<String, dynamic> json) {
    return PaginatedEntities(
      entities: (json['entities'] as List)
          .map((e) => Entity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      perPage: json['per_page'] as int,
    );
  }
}
