import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:outlier/auth/auth.dart';
import 'package:outlier/auth/permissions.dart';
import 'package:outlier/config/schema_cache.dart';
import 'package:outlier/config/schema_loader.dart';
import 'package:outlier/db/database.dart';
import 'package:outlier/db/entity_queries.dart';
import 'package:outlier/db/relationship_queries.dart';
import 'package:outlier/api/router.dart';
import 'package:outlier/api/plugin_handler.dart';

/// Static file handler for the Flutter web build.
/// Falls back to index.html for client-side routing.
Handler _staticFileHandler(String webRoot) {
  return (Request request) {
    var path = request.url.path;
    if (path.isEmpty) path = 'index.html';

    final file = File('$webRoot/$path');
    if (file.existsSync()) {
      final contentType = _mimeType(path);
      return Response.ok(
        file.openRead(),
        headers: {'Content-Type': contentType},
      );
    }

    // SPA fallback — serve index.html for unmatched routes
    final index = File('$webRoot/index.html');
    if (index.existsSync()) {
      return Response.ok(
        index.openRead(),
        headers: {'Content-Type': 'text/html'},
      );
    }

    return Response.notFound('Not found');
  };
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

/// CORS middleware — allows browser requests from any origin (dev mode).
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };

      // Handle preflight OPTIONS requests.
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }

      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final databaseUrl = Platform.environment['DATABASE_URL'] ??
      'postgresql://localhost:5432/outlier';
  final jwtSecret = Platform.environment['JWT_SECRET'];

  // 1. Connect to database
  final db = await Database.connect(databaseUrl);
  stderr.writeln('Connected to database');

  // 2. Run migrations
  await db.migrate();
  stderr.writeln('Migrations complete');

  // 3. Auth migrations (users table)
  final auth = Auth(db: db, jwtSecret: jwtSecret);
  await auth.migrate();

  // 4. Read and validate schema.config
  final configFile = File('schema.config');
  if (!configFile.existsSync()) {
    stderr.writeln('ERROR: schema.config not found');
    exit(1);
  }
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;

  final validation = SchemaLoader.validate(config);
  if (!validation.isValid) {
    stderr.writeln('ERROR: Invalid schema.config:');
    for (final error in validation.errors) {
      stderr.writeln('  - $error');
    }
    exit(1);
  }

  // 5. Sync config to database
  await SchemaLoader.syncToDatabase(config, db);
  stderr.writeln('Schema synced to database');

  // 6. Populate cache
  final cache = SchemaCache();
  cache.refresh(config);

  // 7. Construct query classes
  final entityQueries = EntityQueries(db: db, cache: cache);
  final relationshipQueries = RelationshipQueries(db: db, cache: cache);

  // 8. Permission resolver
  var permissionResolver = PermissionResolver(rules: cache.permissionRules);

  // 9. Build router
  final handler = buildRouter(
    auth: auth,
    db: db,
    cache: cache,
    entityQueries: entityQueries,
    relationshipQueries: relationshipQueries,
    permissionResolver: permissionResolver,
    onSchemaReloaded: () {
      permissionResolver = PermissionResolver(rules: cache.permissionRules);
    },
  );

  // Give plugin handler a reference to the database
  // (it needs it for syncToDatabase)
  // This is done via the router's plugin handler instance

  // 10. Start server
  final pipeline = const Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(handler);

  final server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
  stderr.writeln('API server listening on port ${server.port}');

  // 11. Optionally serve Flutter web frontend on a separate port
  final webPortStr = Platform.environment['WEB_PORT'];
  final webPort = int.tryParse(webPortStr ?? '');
  final webDir = Directory('web');
  if (webPort != null && webDir.existsSync()) {
    final webHandler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(_staticFileHandler(webDir.path));
    final webServer =
        await shelf_io.serve(webHandler, InternetAddress.anyIPv4, webPort);
    stderr.writeln('Web server listening on port ${webServer.port}');
  }

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    stderr.writeln('Shutting down...');
    server.close();
    await db.close();
    exit(0);
  });
}
