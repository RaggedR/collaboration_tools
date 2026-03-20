import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'database.dart';
import '../config/schema_cache.dart';
import '../models/relationship.dart';

class RelationshipQueries {
  final Database db;
  final SchemaCache cache;

  RelationshipQueries({required this.db, required this.cache});

  Future<Relationship> create({
    required String relTypeKey,
    required String sourceEntityId,
    required String targetEntityId,
    required String createdBy,
    Map<String, dynamic> metadata = const {},
  }) async {
    // Validate rel type exists
    final relType = cache.getRelType(relTypeKey);
    if (relType == null) {
      throw ArgumentError('Unknown relationship type: $relTypeKey');
    }

    // Look up source entity and validate type
    final sourceResult = await db.query(
      Sql.named('SELECT type FROM entities WHERE id = @id'),
      parameters: {'id': sourceEntityId},
    );
    if (sourceResult.isEmpty) {
      throw StateError('Source entity not found: $sourceEntityId');
    }
    final sourceType = sourceResult.first.toColumnMap()['type'] as String;
    if (!relType.sourceTypes.contains(sourceType)) {
      throw ArgumentError(
          'Source entity type "$sourceType" not allowed for relationship "$relTypeKey" '
          '(expected: ${relType.sourceTypes})');
    }

    // Look up target entity and validate type
    final targetResult = await db.query(
      Sql.named('SELECT type FROM entities WHERE id = @id'),
      parameters: {'id': targetEntityId},
    );
    if (targetResult.isEmpty) {
      throw StateError('Target entity not found: $targetEntityId');
    }
    final targetType = targetResult.first.toColumnMap()['type'] as String;
    if (!relType.targetTypes.contains(targetType)) {
      throw ArgumentError(
          'Target entity type "$targetType" not allowed for relationship "$relTypeKey" '
          '(expected: ${relType.targetTypes})');
    }

    final result = await db.query(
      Sql.named('''
        INSERT INTO relationships (rel_type_key, source_entity_id, target_entity_id, metadata, created_by)
        VALUES (@relTypeKey, @sourceEntityId, @targetEntityId, @metadata, @createdBy)
        RETURNING *
      '''),
      parameters: {
        'relTypeKey': relTypeKey,
        'sourceEntityId': sourceEntityId,
        'targetEntityId': targetEntityId,
        'metadata': jsonEncode(metadata),
        'createdBy': createdBy,
      },
    );

    return _rowToRelationship(result.first);
  }

  Future<List<Relationship>> list({
    String? entityId,
    String? relType,
    int? page,
    int? perPage,
  }) async {
    final conditions = <String>[];
    final params = <String, dynamic>{};

    if (entityId != null) {
      conditions
          .add('(source_entity_id = @entityId OR target_entity_id = @entityId)');
      params['entityId'] = entityId;
    }
    if (relType != null) {
      conditions.add('rel_type_key = @relType');
      params['relType'] = relType;
    }

    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    var sql = 'SELECT * FROM relationships $where ORDER BY created_at';

    if (page != null && perPage != null) {
      final offset = (page - 1) * perPage;
      params['limit'] = perPage;
      params['offset'] = offset;
      sql += ' LIMIT @limit OFFSET @offset';
    }

    final result = await db.query(Sql.named(sql), parameters: params);
    return result.map(_rowToRelationship).toList();
  }

  Future<void> delete(String id) async {
    await db.execute(
      Sql.named('DELETE FROM relationships WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Relationship _rowToRelationship(ResultRow row) {
    final m = row.toColumnMap();
    return Relationship(
      id: m['id'] as String,
      relTypeKey: m['rel_type_key'] as String,
      sourceEntityId: m['source_entity_id'] as String,
      targetEntityId: m['target_entity_id'] as String,
      metadata: m['metadata'] as Map<String, dynamic>? ?? {},
      createdBy: m['created_by'] as String?,
      createdAt: m['created_at'] as DateTime,
    );
  }
}
