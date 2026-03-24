@Tags(['e2e'])
import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for the plugin system (install/export).
///
/// Plugins are JSON configs (schema.config format) that reconfigure the
/// CMS for a different use case. Installing a plugin changes entity types,
/// rel types, and permission rules — but does NOT delete existing entities.
void main() {
  late TestServer server;
  late TestClient admin;
  late TestClient user;

  setUpAll(() async {
    server = TestServer();
    await server.start();

    admin = TestClient(baseUrl: server.baseUrl);
    await admin.register(email: adminEmail, password: adminPassword, name: adminName);

    user = TestClient(baseUrl: server.baseUrl);
    await user.register(email: userEmail, password: userPassword, name: userName);
  });

  tearDownAll(() async {
    admin.dispose();
    user.dispose();
    await server.stop();
  });

  // ── GET /api/plugins/export ───────────────────────────────

  group('GET /api/plugins/export', () {
    test('exports the current schema as JSON', () async {
      final response = await admin.exportPlugin();

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('app'));
      expect(body, contains('entity_types'));
      expect(body, contains('rel_types'));
      expect(body, contains('permission_rules'));
    });

    test('exported schema matches current schema', () async {
      final schemaResp = await admin.getSchema();
      final exportResp = await admin.exportPlugin();

      final schema = jsonDecode(schemaResp.body) as Map<String, dynamic>;
      final exported = jsonDecode(exportResp.body) as Map<String, dynamic>;

      // App config should match
      expect(exported['app']['name'], equals(schema['app']['name']));

      // Entity type count should match
      expect(
        (exported['entity_types'] as List).length,
        equals((schema['entity_types'] as List).length),
      );
    });
  });

  // ── POST /api/plugins/install ─────────────────────────────

  group('POST /api/plugins/install', () {
    test('installs a new schema config (admin only)', () async {
      final newSchema = alternativeValidSchema();

      final response = await admin.installPlugin(newSchema);

      expect(response.statusCode, equals(200));

      // Verify the schema has changed
      final schemaResp = await admin.getSchema();
      final schema = jsonDecode(schemaResp.body) as Map<String, dynamic>;

      expect(schema['app']['name'], equals('Grant Writer'));

      final entityKeys = (schema['entity_types'] as List)
          .map((et) => (et as Map)['key'])
          .toSet();
      expect(entityKeys, contains('grant'));
      expect(entityKeys, contains('funder'));
    });

    test('returns 403 when non-admin tries to install', () async {
      final response = await user.installPlugin(alternativeValidSchema());

      expect(response.statusCode, equals(403));
    });

    test('rejects invalid schema config', () async {
      final invalidSchema = schemaMissingApp();

      final response = await admin.installPlugin(invalidSchema);

      expect(response.statusCode, equals(400));
    });

    test('rejects schema with broken cross-references', () async {
      final brokenSchema = schemaRelTypeInvalidSourceType();

      final response = await admin.installPlugin(brokenSchema);

      expect(response.statusCode, equals(400));
    });

    test('existing entities survive schema change', () async {
      // Create an entity under the current schema
      final createResp = await user.createEntity(
        type: 'task',
        name: 'Survivor',
        metadata: {'status': 'backlog'},
      );
      expect(createResp.statusCode, equals(201));

      final entityId = ((jsonDecode(createResp.body) as Map)['entity']
              as Map?)?['id'] ??
          (jsonDecode(createResp.body) as Map)['id'];

      // Install a different schema (grant-writing)
      await admin.installPlugin(alternativeValidSchema());

      // The entity should still be retrievable by ID even though
      // its type may no longer be in the schema
      final getResp = await user.getEntity(entityId);
      expect(getResp.statusCode, equals(200));

      final entity =
          (jsonDecode(getResp.body) as Map)['entity'] as Map<String, dynamic>;
      expect(entity['name'], equals('Survivor'));
    });

    test('schema changes are reflected in /api/schema immediately', () async {
      // Install the grant-writing schema
      await admin.installPlugin(alternativeValidSchema());

      final schemaResp = await admin.getSchema();
      final schema = jsonDecode(schemaResp.body) as Map<String, dynamic>;

      expect(schema['app']['name'], equals('Grant Writer'));

      // The new entity types should be available
      final relTypes = schema['rel_types'] as List;
      final relKeys = relTypes.map((rt) => (rt as Map)['key']).toSet();
      expect(relKeys, contains('funded_by'));
    });
  });

  // ── Round-trip: export → install ──────────────────────────

  group('round-trip', () {
    test('exporting and re-installing produces the same schema', () async {
      // Export current schema
      final exportResp = await admin.exportPlugin();
      final exported = jsonDecode(exportResp.body) as Map<String, dynamic>;

      // Install a different schema first
      await admin.installPlugin(alternativeValidSchema());

      // Re-install the exported schema
      final reinstallResp = await admin.installPlugin(exported);
      expect(reinstallResp.statusCode, equals(200));

      // Verify it matches the original
      final schemaResp = await admin.getSchema();
      final schema = jsonDecode(schemaResp.body) as Map<String, dynamic>;

      expect(schema['app']['name'], equals(exported['app']['name']));
      expect(
        (schema['entity_types'] as List).length,
        equals((exported['entity_types'] as List).length),
      );
    });
  });
}
