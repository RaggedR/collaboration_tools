import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth.dart';
import '../auth/permissions.dart';
import '../config/schema_cache.dart';
import '../db/database.dart';
import '../db/entity_queries.dart';
import '../db/relationship_queries.dart';
import 'entity_handler.dart';
import 'relationship_handler.dart';
import 'schema_handler.dart';
import 'plugin_handler.dart';
import 'upload_handler.dart';

Handler buildRouter({
  required Auth auth,
  required Database db,
  required SchemaCache cache,
  required EntityQueries entityQueries,
  required RelationshipQueries relationshipQueries,
  required PermissionResolver permissionResolver,
  required Function() onSchemaReloaded,
}) {
  final router = Router();

  final entityHandler = EntityHandler(
    entities: entityQueries,
    cache: cache,
    resolver: permissionResolver,
  );
  final relHandler = RelationshipHandler(relationships: relationshipQueries);
  final schemaHandler = SchemaHandler(cache: cache);
  final pluginHandler = PluginHandler(
    cache: cache,
    onSchemaReloaded: onSchemaReloaded,
  )..setDatabase(db);
  final uploadHandler = UploadHandler();

  // Auth (no middleware needed)
  router.post('/api/auth/register', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await auth.register(
        email: body['email'] as String,
        password: body['password'] as String,
        name: body['name'] as String? ?? 'User',
      );
      return _json(result, status: 201);
    } catch (e) {
      return _error('REGISTRATION_ERROR', e.toString(), status: 400);
    }
  });

  router.post('/api/auth/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await auth.login(
        email: body['email'] as String,
        password: body['password'] as String,
      );
      return _json(result);
    } catch (e) {
      return _error('AUTH_ERROR', 'Invalid credentials', status: 401);
    }
  });

  router.get('/api/auth/me', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return _json(user);
  });

  // Schema (no auth required)
  router.get('/api/schema', schemaHandler.getSchema);
  router.get('/api/entity-types', schemaHandler.getEntityTypes);
  router.get('/api/rel-types', schemaHandler.getRelTypes);

  // Entities (auth required)
  router.get('/api/entities', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return entityHandler.list(request);
  });

  router.get('/api/entities/<id>', (Request request, String id) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return entityHandler.get(request, id);
  });

  router.post('/api/entities', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return entityHandler.create(request, user);
  });

  router.put('/api/entities/<id>', (Request request, String id) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return entityHandler.update(request, id, user);
  });

  router.delete('/api/entities/<id>', (Request request, String id) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return entityHandler.delete(request, id, user);
  });

  // Relationships (auth required)
  router.get('/api/relationships', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return relHandler.list(request);
  });

  router.post('/api/relationships', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return relHandler.create(request, user);
  });

  router.delete('/api/relationships/<id>',
      (Request request, String id) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return relHandler.delete(request, id);
  });

  // Plugins (auth required, admin-only for install)
  router.get('/api/plugins/export', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return pluginHandler.export(request);
  });

  router.post('/api/plugins/install', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    if (user['is_admin'] != true) {
      return _error('FORBIDDEN', 'Admin access required', status: 403);
    }
    return pluginHandler.install(request);
  });

  // Upload (auth required)
  router.post('/api/upload', (Request request) async {
    final user = await _authenticate(request, auth);
    if (user == null) return _unauthorized();
    return uploadHandler.upload(request);
  });

  // Serve uploaded files (no auth — static assets)
  router.get('/uploads/<filename>', (Request request, String filename) {
    return uploadHandler.serve(request, filename);
  });

  // Serve Flutter web build as SPA fallback
  final webDir = Directory('web');
  if (webDir.existsSync()) {
    router.all('/<path|.*>', (Request request, String path) {
      final file = File('web/$path');
      if (file.existsSync()) {
        return Response.ok(file.openRead(), headers: {
          'Content-Type': _mimeType(path),
        });
      }
      // SPA fallback — serve index.html for client-side routing
      final index = File('web/index.html');
      if (index.existsSync()) {
        return Response.ok(index.openRead(), headers: {
          'Content-Type': 'text/html',
        });
      }
      return Response.notFound('Not found');
    });
  }

  return router.call;
}

Future<Map<String, dynamic>?> _authenticate(
    Request request, Auth auth) async {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  final token = authHeader.substring(7);
  return auth.getUserFromToken(token);
}

Response _json(Object body, {int status = 200}) {
  return Response(status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'});
}

Response _error(String code, String message, {int status = 400, String? field}) {
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

Response _unauthorized() {
  return _error('UNAUTHORIZED', 'Authentication required', status: 401);
}

String _mimeType(String path) {
  if (path.endsWith('.html')) return 'text/html';
  if (path.endsWith('.js')) return 'application/javascript';
  if (path.endsWith('.css')) return 'text/css';
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.ico')) return 'image/x-icon';
  if (path.endsWith('.woff2')) return 'font/woff2';
  if (path.endsWith('.woff')) return 'font/woff';
  if (path.endsWith('.ttf')) return 'font/ttf';
  return 'application/octet-stream';
}
