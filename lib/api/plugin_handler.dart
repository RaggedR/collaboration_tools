import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/schema_cache.dart';
import '../config/schema_loader.dart';
import '../db/database.dart';

class PluginHandler {
  final SchemaCache cache;
  final Function() onSchemaReloaded;
  Database? _db;

  PluginHandler({
    required this.cache,
    required this.onSchemaReloaded,
  });

  void setDatabase(Database db) => _db = db;

  Future<Response> install(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    // Validate the new config
    final result = SchemaLoader.validate(body);
    if (!result.isValid) {
      return Response(400,
          body: jsonEncode({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': result.errors.join('; '),
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // Sync to database and refresh cache
    try {
      await SchemaLoader.syncToDatabase(body, _db!);
      cache.refresh(body);
      onSchemaReloaded();
    } catch (e) {
      return Response(500,
          body: jsonEncode({
            'error': {
              'code': 'SYNC_ERROR',
              'message': e.toString(),
            }
          }),
          headers: {'Content-Type': 'application/json'});
    }

    // Return the new schema
    return Response.ok(
      jsonEncode({
        'app': cache.appConfig,
        'entity_types': cache.entityTypes.map((et) => et.toJson()).toList(),
        'rel_types': cache.relTypes.map((rt) => rt.toJson()).toList(),
        'permission_rules':
            cache.permissionRules.map((r) => r.toJson()).toList(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> export(Request request) async {
    return Response.ok(
      jsonEncode({
        'app': cache.appConfig,
        'entity_types': cache.entityTypes.map((et) => et.toJson()).toList(),
        'rel_types': cache.relTypes.map((rt) => rt.toJson()).toList(),
        'permission_rules':
            cache.permissionRules.map((r) => r.toJson()).toList(),
        'auto_relationships': cache.autoRelationships,
        'seed_data': {'entities': [], 'relationships': []},
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
