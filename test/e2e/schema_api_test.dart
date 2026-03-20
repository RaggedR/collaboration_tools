import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for schema discovery endpoints.
///
/// These verify that the frontend can discover the CMS configuration
/// from the API. The frontend calls GET /api/schema on startup and
/// uses the response to build its entire UI.
void main() {
  late TestServer server;
  late TestClient client;

  setUpAll(() async {
    server = TestServer();
    await server.start();
    client = TestClient(baseUrl: server.baseUrl);

    // Register and login as a regular user
    await client.register(
      email: userEmail,
      password: userPassword,
      name: userName,
    );
  });

  tearDownAll(() async {
    client.dispose();
    await server.stop();
  });

  group('GET /api/schema', () {
    test('returns 200 with full schema', () async {
      final response = await client.getSchema();

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('app'));
      expect(body, contains('entity_types'));
      expect(body, contains('rel_types'));
      expect(body, contains('permission_rules'));
    });

    test('includes app config with name and theme', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final app = body['app'] as Map<String, dynamic>;

      expect(app['name'], equals('Outlier'));
      expect(app['description'], isA<String>());
      expect(app['theme_color'], matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
    });

    test('entity types include all required fields', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entityTypes = body['entity_types'] as List;

      expect(entityTypes, isNotEmpty);

      for (final et in entityTypes) {
        final entityType = et as Map<String, dynamic>;
        expect(entityType, contains('key'));
        expect(entityType, contains('label'));
        expect(entityType, contains('plural'));
        expect(entityType, contains('icon'));
        expect(entityType, contains('color'));
        expect(entityType, contains('hidden'));
      }
    });

    test('returns all 6 entity types from schema.config', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entityTypes = body['entity_types'] as List;
      final keys = entityTypes.map((et) => (et as Map)['key']).toSet();

      expect(keys, containsAll([
        'workspace', 'project', 'sprint', 'task', 'document', 'person',
      ]));
    });

    test('returns all 11 relationship types from schema.config', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final relTypes = body['rel_types'] as List;
      final keys = relTypes.map((rt) => (rt as Map)['key']).toSet();

      expect(relTypes, hasLength(11));
      expect(keys, contains('assigned_to'));
      expect(keys, contains('depends_on'));
      expect(keys, contains('collaborates'));
    });

    test('rel types include source/target type constraints', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final relTypes = body['rel_types'] as List;

      final assignedTo = relTypes.firstWhere(
        (rt) => (rt as Map)['key'] == 'assigned_to',
      ) as Map<String, dynamic>;

      expect(assignedTo['source_types'], equals(['task']));
      expect(assignedTo['target_types'], equals(['person']));
      expect(assignedTo['forward_label'], equals('assigned to'));
      expect(assignedTo['reverse_label'], equals('responsible for'));
      expect(assignedTo['symmetric'], isFalse);
    });

    test('permission rules are included', () async {
      final response = await client.getSchema();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rules = body['permission_rules'] as List;

      expect(rules, hasLength(4));

      // Check that workspace is admin-only
      final adminOnlyWorkspace = rules.any((r) =>
          (r as Map)['rule_type'] == 'admin_only_entity_type' &&
          r['entity_type_key'] == 'workspace');
      expect(adminOnlyWorkspace, isTrue);

      // Check that assigned_to grants edit
      final editGranting = rules.any((r) =>
          (r as Map)['rule_type'] == 'edit_granting_rel_type' &&
          r['rel_type_key'] == 'assigned_to');
      expect(editGranting, isTrue);
    });
  });

  group('GET /api/entity-types', () {
    test('returns only entity types (subset of /api/schema)', () async {
      final response = await client.getEntityTypes();

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as List;
      expect(body, hasLength(6));
      expect(body.first, contains('key'));
      expect(body.first, contains('label'));
    });
  });

  group('GET /api/rel-types', () {
    test('returns only relationship types (subset of /api/schema)', () async {
      final response = await client.getRelTypes();

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as List;
      expect(body, hasLength(11));
      expect(body.first, contains('key'));
      expect(body.first, contains('forward_label'));
    });
  });

  group('Schema is accessible without auth', () {
    test('GET /api/schema works without auth token', () async {
      final unauthClient = TestClient(baseUrl: server.baseUrl);

      final response = await unauthClient.getSchema();

      // Schema must be accessible without auth — the frontend needs it
      // before the user logs in to render the login screen with branding
      expect(response.statusCode, equals(200));

      unauthClient.dispose();
    });
  });
}
