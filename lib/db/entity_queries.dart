import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'database.dart';
import '../config/schema_cache.dart';
import '../config/metadata_validator.dart';
import '../models/entity.dart';

class EntityQueries {
  final Database db;
  final SchemaCache cache;

  EntityQueries({required this.db, required this.cache});

  Future<Entity> create({
    required String type,
    required String name,
    required Map<String, dynamic> metadata,
    required String createdBy,
    String? body,
  }) async {
    // Validate type exists (cache first, then database)
    final entityType = cache.getEntityType(type);
    if (entityType == null) {
      // Type not in cache — check if it exists in database (orphaned from prior config)
      final typeCheck = await db.query(
        Sql.named('SELECT key FROM entity_types WHERE key = @key'),
        parameters: {'key': type},
      );
      if (typeCheck.isEmpty) {
        throw ArgumentError('Unknown entity type: $type');
      }
      // Type exists in DB but not in current config — skip metadata validation
    } else {
      // Validate metadata against cached schema
      final validation =
          MetadataValidator.validate(entityType.metadataSchema, metadata);
      if (!validation.isValid) {
        throw ArgumentError(
            'Invalid metadata: ${validation.errors.join(', ')}');
      }
    }

    final result = await db.query(
      Sql.named('''
        INSERT INTO entities (type, name, body, metadata, created_by)
        VALUES (@type, @name, @body, @metadata, @createdBy)
        RETURNING *
      '''),
      parameters: {
        'type': type,
        'name': name,
        'body': body,
        'metadata': jsonEncode(metadata),
        'createdBy': createdBy,
      },
    );

    final entity = _rowToEntity(result.first);

    // Check auto-relationships
    for (final ar in cache.autoRelationships) {
      if (ar['trigger'] == 'create' && ar['entity_type'] == type) {
        final relTypeKey = ar['rel_type_key'] as String;
        final target = ar['target'] as String;

        if (target == 'current_user') {
          // Find the person entity linked to this user
          final personResult = await db.query(
            Sql.named('''
              SELECT id FROM entities
              WHERE type = 'person' AND created_by = @createdBy
              LIMIT 1
            '''),
            parameters: {'createdBy': createdBy},
          );

          if (personResult.isNotEmpty) {
            final personId = personResult.first.toColumnMap()['id'] as String;

            // Determine correct direction: check if the rel type's
            // source includes the entity type or the person type.
            final relType = cache.getRelType(relTypeKey);
            final personIsSource = relType != null &&
                relType.sourceTypes.contains('person') &&
                relType.targetTypes.contains(type);

            await db.query(
              Sql.named('''
                INSERT INTO relationships (rel_type_key, source_entity_id, target_entity_id, created_by)
                VALUES (@relTypeKey, @sourceId, @targetId, @createdBy)
              '''),
              parameters: {
                'relTypeKey': relTypeKey,
                'sourceId': personIsSource ? personId : entity.id,
                'targetId': personIsSource ? entity.id : personId,
                'createdBy': createdBy,
              },
            );
          }
        }
      }
    }

    return entity;
  }

  Future<Entity> get(String id) async {
    final result = await db.query(
      Sql.named('SELECT * FROM entities WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) throw StateError('Entity not found: $id');
    return _rowToEntity(result.first);
  }

  Future<EntityWithRelationships> getWithRelationships(String id) async {
    final entity = await get(id);

    // Get all relationships where this entity is source or target
    final result = await db.query(
      Sql.named('''
        SELECT r.*,
          CASE WHEN r.source_entity_id = @id THEN 'forward' ELSE 'reverse' END as direction,
          CASE WHEN r.source_entity_id = @id THEN e_target.id ELSE e_source.id END as related_id,
          CASE WHEN r.source_entity_id = @id THEN e_target.type ELSE e_source.type END as related_type,
          CASE WHEN r.source_entity_id = @id THEN e_target.name ELSE e_source.name END as related_name
        FROM relationships r
        JOIN entities e_source ON r.source_entity_id = e_source.id
        JOIN entities e_target ON r.target_entity_id = e_target.id
        WHERE r.source_entity_id = @id OR r.target_entity_id = @id
      '''),
      parameters: {'id': id},
    );

    final relationships = result.map((row) {
      final m = row.toColumnMap();
      final direction = m['direction'] as String;
      final relTypeKey = m['rel_type_key'] as String;
      final relType = cache.getRelType(relTypeKey);
      final label = direction == 'forward'
          ? (relType?.forwardLabel ?? relTypeKey)
          : (relType?.reverseLabel ?? relTypeKey);

      return ResolvedRelationship(
        id: m['id'] as String,
        relTypeKey: relTypeKey,
        direction: direction,
        label: label,
        relatedEntity: RelatedEntity(
          id: m['related_id'] as String,
          type: m['related_type'] as String,
          name: m['related_name'] as String,
        ),
        metadata: m['metadata'] as Map<String, dynamic>? ?? {},
      );
    }).toList();

    return EntityWithRelationships(
      entity: entity,
      relationships: relationships,
    );
  }

  Future<Entity> update(
    String id, {
    String? name,
    String? body,
    bool clearBody = false,
    Map<String, dynamic>? metadata,
  }) async {
    // Get the current entity to know its type
    final current = await get(id);

    // Validate metadata if provided
    if (metadata != null) {
      final entityType = cache.getEntityType(current.type);
      if (entityType != null) {
        final validation =
            MetadataValidator.validate(entityType.metadataSchema, metadata);
        if (!validation.isValid) {
          throw ArgumentError(
              'Invalid metadata: ${validation.errors.join(', ')}');
        }
      }
    }

    final result = await db.query(
      Sql.named('''
        UPDATE entities SET
          name = COALESCE(@name, name),
          body = ${clearBody ? '@body' : 'COALESCE(@body, body)'},
          metadata = COALESCE(@metadata, metadata),
          updated_at = NOW()
        WHERE id = @id
        RETURNING *
      '''),
      parameters: {
        'id': id,
        'name': name,
        'body': body,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
      },
    );

    if (result.isEmpty) throw StateError('Entity not found: $id');
    return _rowToEntity(result.first);
  }

  Future<void> delete(String id) async {
    await db.execute(
      Sql.named('DELETE FROM entities WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<PaginatedEntities> list({
    String? type,
    String? search,
    Map<String, dynamic>? metadata,
    String? relatedTo,
    String? relType,
    int page = 1,
    int perPage = 50,
  }) async {
    final conditions = <String>[];
    final params = <String, dynamic>{};
    var fromClause = 'entities';

    if (type != null) {
      conditions.add('entities.type = @type');
      params['type'] = type;
    }
    if (search != null) {
      conditions.add('entities.name ILIKE @search');
      params['search'] = '%$search%';
    }
    if (metadata != null && metadata.isNotEmpty) {
      conditions.add('entities.metadata @> @metadataFilter::jsonb');
      params['metadataFilter'] = jsonEncode(metadata);
    }

    // related_to filter: JOIN relationships table
    if (relatedTo != null && relType != null) {
      fromClause = '''entities
        JOIN relationships ON (
          (relationships.source_entity_id = entities.id AND relationships.target_entity_id = @relatedTo)
          OR (relationships.target_entity_id = entities.id AND relationships.source_entity_id = @relatedTo)
        )''';
      conditions.add('relationships.rel_type_key = @relType');
      params['relatedTo'] = relatedTo;
      params['relType'] = relType;
    }

    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    // Count total
    final countResult = await db.query(
      Sql.named('SELECT COUNT(DISTINCT entities.id) as count FROM $fromClause $where'),
      parameters: params,
    );
    final total = countResult.first.toColumnMap()['count'] as int;

    // Fetch page
    final offset = (page - 1) * perPage;
    params['limit'] = perPage;
    params['offset'] = offset;

    // Exclude body from list queries — it can be large; load on detail GET only.
    final result = await db.query(
      Sql.named(
          'SELECT DISTINCT entities.id, entities.type, entities.name, entities.metadata, entities.created_by, entities.created_at, entities.updated_at FROM $fromClause $where ORDER BY entities.created_at DESC LIMIT @limit OFFSET @offset'),
      parameters: params,
    );

    return PaginatedEntities(
      entities: result.map(_rowToEntity).toList(),
      total: total,
    );
  }

  Entity _rowToEntity(ResultRow row) {
    final m = row.toColumnMap();
    return Entity(
      id: m['id'] as String,
      type: m['type'] as String,
      name: m['name'] as String,
      body: m.containsKey('body') ? m['body'] as String? : null,
      metadata: m['metadata'] as Map<String, dynamic>? ?? {},
      createdBy: m['created_by'] as String?,
      createdAt: m['created_at'] as DateTime,
      updatedAt: m['updated_at'] as DateTime,
    );
  }
}
