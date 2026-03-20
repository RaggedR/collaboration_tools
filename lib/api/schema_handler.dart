import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/schema_cache.dart';

class SchemaHandler {
  final SchemaCache cache;

  SchemaHandler({required this.cache});

  Future<Response> getSchema(Request request) async {
    return _json({
      'app': cache.appConfig,
      'entity_types': cache.entityTypes.map((et) => et.toJson()).toList(),
      'rel_types': cache.relTypes.map((rt) => rt.toJson()).toList(),
      'permission_rules':
          cache.permissionRules.map((r) => r.toJson()).toList(),
    });
  }

  Future<Response> getEntityTypes(Request request) async {
    return _json(cache.entityTypes.map((et) => et.toJson()).toList());
  }

  Future<Response> getRelTypes(Request request) async {
    return _json(cache.relTypes.map((rt) => rt.toJson()).toList());
  }

  Response _json(Object body) {
    return Response.ok(
      jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
