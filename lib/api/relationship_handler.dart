import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../db/relationship_queries.dart';

class RelationshipHandler {
  final RelationshipQueries relationships;

  RelationshipHandler({required this.relationships});

  Future<Response> list(Request request) async {
    final params = request.url.queryParameters;

    final result = await relationships.list(
      entityId: params['entity_id'],
      relType: params['rel_type'],
      page: int.tryParse(params['page'] ?? ''),
      perPage: int.tryParse(params['per_page'] ?? ''),
    );

    return _json(result.map((r) => r.toJson()).toList());
  }

  Future<Response> create(
      Request request, Map<String, dynamic> user) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    try {
      final rel = await relationships.create(
        relTypeKey: body['rel_type_key'] as String,
        sourceEntityId: body['source_entity_id'] as String,
        targetEntityId: body['target_entity_id'] as String,
        createdBy: user['id'] as String,
        metadata:
            body['metadata'] as Map<String, dynamic>? ?? {},
      );
      return _json(rel.toJson(), status: 201);
    } on ArgumentError catch (e) {
      return _error('VALIDATION_ERROR', e.message);
    } on StateError catch (e) {
      final message = e.message;
      if (message.contains('not found')) {
        return _error('NOT_FOUND', message, status: 404);
      }
      return _error('VALIDATION_ERROR', message);
    }
  }

  Future<Response> delete(Request request, String id) async {
    await relationships.delete(id);
    return Response(200,
        body: jsonEncode({'deleted': true}),
        headers: {'Content-Type': 'application/json'});
  }

  Response _json(Object body, {int status = 200}) {
    return Response(status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }

  Response _error(String code, String message,
      {int status = 400}) {
    return Response(status,
        body: jsonEncode({
          'error': {'code': code, 'message': message}
        }),
        headers: {'Content-Type': 'application/json'});
  }
}
