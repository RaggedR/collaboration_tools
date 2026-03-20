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
      .addMiddleware(logRequests())
      .addHandler(handler);

  final server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
  stderr.writeln('Server listening on port ${server.port}');

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    stderr.writeln('Shutting down...');
    server.close();
    await db.close();
    exit(0);
  });
}
