import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../config/schema_cache.dart';
import '../auth/permissions.dart';
import '../db/entity_queries.dart';

class EntityHandler {
  final EntityQueries entities;
  final SchemaCache cache;
  final PermissionResolver resolver;

  EntityHandler({
    required this.entities,
    required this.cache,
    required this.resolver,
  });

  Future<Response> list(Request request) async {
    final params = request.url.queryParameters;
    Map<String, dynamic>? metadata;
    if (params['metadata'] != null) {
      metadata = jsonDecode(params['metadata']!) as Map<String, dynamic>;
    }

    final result = await entities.list(
      type: params['type'],
      search: params['search'],
      metadata: metadata,
      relatedTo: params['related_to'],
      relType: params['rel_type'],
      page: int.tryParse(params['page'] ?? '') ?? 1,
      perPage: int.tryParse(params['per_page'] ?? '') ?? 50,
    );

    return _json({
      'entities': result.entities.map((e) => e.toJson()).toList(),
      'total': result.total,
      'page': int.tryParse(params['page'] ?? '') ?? 1,
      'per_page': int.tryParse(params['per_page'] ?? '') ?? 50,
    });
  }

  Future<Response> get(Request request, String id) async {
    try {
      final result = await entities.getWithRelationships(id);
      return _json({
        'entity': result.entity.toJson(),
        'relationships':
            result.relationships.map((r) => r.toJson()).toList(),
      });
    } on StateError {
      return _error('NOT_FOUND', 'Entity not found', status: 404);
    }
  }

  Future<Response> create(
      Request request, Map<String, dynamic> user) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final type = body['type'] as String?;
    final name = body['name'] as String?;
    final entityBody = body['body'] as String?;
    final metadata =
        body['metadata'] as Map<String, dynamic>? ?? {};

    if (type == null || name == null) {
      return _error('VALIDATION_ERROR', 'type and name are required');
    }

    // Permission check (only applies if type is in current config)
    final isAdmin = user['is_admin'] as bool? ?? false;
    if (cache.hasEntityType(type) &&
        !resolver.canCreate(entityType: type, isAdmin: isAdmin)) {
      return _error('FORBIDDEN', 'Admin access required for type: $type',
          status: 403);
    }

    try {
      final entity = await entities.create(
        type: type,
        name: name,
        body: entityBody,
        metadata: metadata,
        createdBy: user['id'] as String,
      );
      return _json({'entity': entity.toJson()}, status: 201);
    } on ArgumentError catch (e) {
      return _error('VALIDATION_ERROR', e.message);
    }
  }

  Future<Response> update(
      Request request, String id, Map<String, dynamic> user) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final isAdmin = user['is_admin'] as bool? ?? false;

    // Check entity exists and get its type
    try {
      final existing = await entities.get(id);

      // Permission check
      if (!isAdmin) {
        // Creator can always edit their own entity
        final currentUserId = user['id'] as String?;
        final isCreator = existing.createdBy == currentUserId;

        if (!isCreator) {
          // Check edit-granting relationships
          final personId = user['person_entity_id'] as String?;
          List<String> userRels = [];
          if (personId != null) {
            final entityDetail = await entities.getWithRelationships(id);
            userRels = entityDetail.relationships
                .where((r) => r.relatedEntity.id == personId)
                .map((r) => r.relTypeKey)
                .toList();
          }

          if (!resolver.canEdit(
            entityType: existing.type,
            isAdmin: false,
            userRelationships: userRels,
          )) {
            return _error('FORBIDDEN', 'Edit permission denied', status: 403);
          }
        }
      }

      final updated = await entities.update(
        id,
        name: body['name'] as String?,
        body: body['body'] as String?,
        clearBody: body.containsKey('body') && body['body'] == null,
        metadata: body['metadata'] as Map<String, dynamic>?,
      );

      // Auto-archive documents when all parent tasks are done/archived
      if (updated.type == 'task' &&
          (updated.metadata['status'] == 'done' ||
           updated.metadata['status'] == 'archived')) {
        await _autoArchiveDocuments(updated.id);
      }

      return _json({'entity': updated.toJson()});
    } on StateError {
      return _error('NOT_FOUND', 'Entity not found', status: 404);
    } on ArgumentError catch (e) {
      return _error('VALIDATION_ERROR', e.message);
    }
  }

  Future<Response> delete(
      Request request, String id, Map<String, dynamic> user) async {
    try {
      await entities.delete(id);
      return Response(200,
          body: jsonEncode({'deleted': true}),
          headers: {'Content-Type': 'application/json'});
    } on StateError {
      return _error('NOT_FOUND', 'Entity not found', status: 404);
    }
  }

  /// When a task moves to "done", check all documents attached to it
  /// (via contains_doc). If ALL tasks that own a document are "done",
  /// auto-archive the document.
  Future<void> _autoArchiveDocuments(String taskId) async {
    // Find all documents attached to this task via contains_doc
    final docRels = await entities.db.query(
      Sql.named('''
        SELECT target_entity_id FROM relationships
        WHERE source_entity_id = @taskId
          AND rel_type_key = 'contains_doc'
      '''),
      parameters: {'taskId': taskId},
    );

    for (final row in docRels) {
      final docId = row.toColumnMap()['target_entity_id'] as String;

      // Find ALL tasks that own this document
      final parentTasks = await entities.db.query(
        Sql.named('''
          SELECT e.metadata FROM relationships r
          JOIN entities e ON e.id = r.source_entity_id
          WHERE r.target_entity_id = @docId
            AND r.rel_type_key = 'contains_doc'
            AND e.type = 'task'
        '''),
        parameters: {'docId': docId},
      );

      // Check if all parent tasks are "done"
      final allDone = parentTasks.every((r) {
        final meta = r.toColumnMap()['metadata'];
        if (meta is Map<String, dynamic>) {
          return meta['status'] == 'done' || meta['status'] == 'archived';
        }
        return false;
      });

      if (allDone && parentTasks.isNotEmpty) {
        // Archive the document
        final doc = await entities.get(docId);
        if (doc.metadata['status'] != 'archived') {
          await entities.update(
            docId,
            metadata: {...doc.metadata, 'status': 'archived'},
          );
        }
      }
    }
  }

  Response _json(Object body, {int status = 200}) {
    return Response(status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }

  Response _error(String code, String message,
      {int status = 400, String? field}) {
    return Response(status,
        body: jsonEncode({
          'error': {
            'code': code,
            'message': message,
            if (field != null) 'field': field,
          }
        }),
        headers: {'Content-Type': 'application/json'});
  }
}
