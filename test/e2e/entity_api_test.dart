import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for entity CRUD endpoints.
///
/// These test the full HTTP round-trip: create entities, read them back,
/// update them, delete them. They verify status codes, response shapes,
/// pagination, search, filtering, and permission enforcement.
void main() {
  late TestServer server;
  late TestClient admin;
  late TestClient user;

  setUpAll(() async {
    server = TestServer();
    await server.start();

    admin = TestClient(baseUrl: server.baseUrl);
    await admin.register(
      email: adminEmail,
      password: adminPassword,
      name: adminName,
    );

    user = TestClient(baseUrl: server.baseUrl);
    await user.register(
      email: userEmail,
      password: userPassword,
      name: userName,
    );
  });

  tearDownAll(() async {
    admin.dispose();
    user.dispose();
    await server.stop();
  });

  // Helper to extract entity ID from a create response
  String entityId(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    return body['entity']?['id'] ?? body['id'];
  }

  // ── POST /api/entities ────────────────────────────────────

  group('POST /api/entities', () {
    test('creates an entity and returns 201', () async {
      final response = await user.createEntity(
        type: 'task',
        name: 'Write E2E tests',
        metadata: {'status': 'backlog', 'priority': 'high'},
      );

      expect(response.statusCode, equals(201));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('entity'));

      final entity = body['entity'] as Map<String, dynamic>;
      expect(entity['id'], isNotEmpty);
      expect(entity['type'], equals('task'));
      expect(entity['name'], equals('Write E2E tests'));
      expect(entity['metadata']['status'], equals('backlog'));
      expect(entity['created_at'], isNotNull);
      expect(entity['updated_at'], isNotNull);
    });

    test('returns 400 for unknown entity type', () async {
      final response = await user.createEntity(
        type: 'unicorn',
        name: 'Not a thing',
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('error'));
    });

    test('returns 400 when metadata fails schema validation', () async {
      final response = await user.createEntity(
        type: 'task',
        name: 'Bad metadata',
        metadata: {'status': 'nonexistent'},
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['error']['message'], contains('status'));
    });

    test('returns 400 when required metadata fields are missing', () async {
      final response = await user.createEntity(
        type: 'sprint',
        name: 'Missing dates',
        metadata: {'goal': 'Ship it'},
      );

      expect(response.statusCode, equals(400));
    });

    test('returns 403 when non-admin creates admin-only entity type', () async {
      final response = await user.createEntity(
        type: 'workspace',
        name: 'Forbidden workspace',
      );

      expect(response.statusCode, equals(403));
    });

    test('admin can create admin-only entity types', () async {
      final response = await admin.createEntity(
        type: 'workspace',
        name: 'Admin workspace',
        metadata: {'description': 'Test workspace'},
      );

      expect(response.statusCode, equals(201));
    });

    test('admin can create person entities', () async {
      final response = await admin.createEntity(
        type: 'person',
        name: 'Robin',
        metadata: {'email': 'robin@test.com', 'role': 'developer'},
      );

      expect(response.statusCode, equals(201));
    });
  });

  // ── GET /api/entities ─────────────────────────────────────

  group('GET /api/entities', () {
    test('returns paginated list with total count', () async {
      // Create some entities
      for (var i = 0; i < 5; i++) {
        await user.createEntity(type: 'task', name: 'List task $i');
      }

      final response = await user.listEntities(type: 'task', page: 1, perPage: 3);

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('entities'));
      expect(body, contains('total'));
      expect(body, contains('page'));
      expect(body, contains('per_page'));
      expect((body['entities'] as List).length, lessThanOrEqualTo(3));
    });

    test('filters entities by type', () async {
      await user.createEntity(type: 'task', name: 'A task');
      await user.createEntity(type: 'project', name: 'A project');

      final response = await user.listEntities(type: 'task');

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(entities.every((e) => (e as Map)['type'] == 'task'), isTrue);
    });

    test('searches entities by name', () async {
      await user.createEntity(type: 'task', name: 'Build login page');
      await user.createEntity(type: 'task', name: 'Fix logout bug');
      await user.createEntity(type: 'task', name: 'Write docs');

      final response = await user.listEntities(search: 'log');

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      // Should find "login" and "logout"
      expect(
        entities.every((e) =>
            (e as Map)['name'].toString().toLowerCase().contains('log')),
        isTrue,
      );
    });

    test('filters entities by metadata', () async {
      await user.createEntity(type: 'task', name: 'Done', metadata: {'status': 'done'});
      await user.createEntity(type: 'task', name: 'Todo', metadata: {'status': 'todo'});

      final response = await user.listEntities(
        type: 'task',
        metadata: {'status': 'done'},
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(
        entities.every((e) => (e as Map)['metadata']['status'] == 'done'),
        isTrue,
      );
    });

    test('returns empty list for type with no entities', () async {
      final response = await user.listEntities(type: 'document');

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['entities'], isEmpty);
      expect(body['total'], equals(0));
    });
  });

  // ── GET /api/entities/:id ─────────────────────────────────

  group('GET /api/entities/:id', () {
    test('returns entity with its relationships', () async {
      // Create entities
      final taskResp = await user.createEntity(
        type: 'task',
        name: 'Detailed task',
        metadata: {'status': 'in_progress'},
      );
      final taskId = entityId(taskResp.body);

      final personResp = await admin.createEntity(
        type: 'person',
        name: 'Robin',
        metadata: {'email': 'robin@test.com'},
      );
      final personId = entityId(personResp.body);

      // Create relationship
      await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );

      // Fetch the entity detail
      final response = await user.getEntity(taskId);

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('entity'));
      expect(body, contains('relationships'));

      final entity = body['entity'] as Map<String, dynamic>;
      expect(entity['name'], equals('Detailed task'));
      expect(entity['type'], equals('task'));

      final relationships = body['relationships'] as List;
      expect(relationships, isNotEmpty);

      final rel = relationships.first as Map<String, dynamic>;
      expect(rel, contains('id'));
      expect(rel, contains('rel_type_key'));
      expect(rel, contains('direction'));
      expect(rel, contains('label'));
      expect(rel, contains('related_entity'));
    });

    test('returns 404 for non-existent entity', () async {
      final response =
          await user.getEntity('00000000-0000-0000-0000-000000000000');

      expect(response.statusCode, equals(404));
    });
  });

  // ── PUT /api/entities/:id ─────────────────────────────────

  group('PUT /api/entities/:id', () {
    test('updates entity name and metadata', () async {
      final createResp = await user.createEntity(
        type: 'task',
        name: 'Original',
        metadata: {'status': 'backlog'},
      );
      final id = entityId(createResp.body);

      final updateResp = await user.updateEntity(
        id,
        name: 'Updated',
        metadata: {'status': 'in_progress'},
      );

      expect(updateResp.statusCode, equals(200));

      final body = jsonDecode(updateResp.body) as Map<String, dynamic>;
      final entity = body['entity'] as Map<String, dynamic>;
      expect(entity['name'], equals('Updated'));
      expect(entity['metadata']['status'], equals('in_progress'));
    });

    test('returns 400 when updated metadata fails validation', () async {
      final createResp = await user.createEntity(
        type: 'task',
        name: 'Will fail update',
        metadata: {'status': 'backlog'},
      );
      final id = entityId(createResp.body);

      final updateResp = await user.updateEntity(
        id,
        metadata: {'status': 'nonexistent_status'},
      );

      expect(updateResp.statusCode, equals(400));
    });

    test('returns 403 when user lacks edit permission', () async {
      // Create a task as admin (user has no relationship to it)
      final createResp = await admin.createEntity(
        type: 'task',
        name: 'Admin task',
        metadata: {'status': 'backlog'},
      );
      final id = entityId(createResp.body);

      // User tries to edit without an edit-granting relationship
      final updateResp = await user.updateEntity(
        id,
        name: 'Attempted edit',
      );

      expect(updateResp.statusCode, equals(403));
    });
  });

  // ── DELETE /api/entities/:id ──────────────────────────────

  group('DELETE /api/entities/:id', () {
    test('deletes entity and returns success', () async {
      final createResp = await user.createEntity(
        type: 'task',
        name: 'Delete me',
      );
      final id = entityId(createResp.body);

      final deleteResp = await user.deleteEntity(id);

      expect(deleteResp.statusCode, anyOf(200, 204));

      // Verify it's gone
      final getResp = await user.getEntity(id);
      expect(getResp.statusCode, equals(404));
    });

    test('deleting entity also removes its relationships', () async {
      final taskResp = await user.createEntity(type: 'task', name: 'Doomed');
      final taskId = entityId(taskResp.body);

      final personResp = await admin.createEntity(type: 'person', name: 'P');
      final personId = entityId(personResp.body);

      await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );

      // Delete the task
      await user.deleteEntity(taskId);

      // Person's relationships should no longer reference the deleted task
      final personDetail = await user.getEntity(personId);
      final body = jsonDecode(personDetail.body) as Map<String, dynamic>;
      final rels = body['relationships'] as List;

      // No relationships pointing to the deleted task
      expect(
        rels.where((r) =>
            (r as Map)['related_entity']?['id'] == taskId).toList(),
        isEmpty,
      );
    });
  });

  // ── Error format ──────────────────────────────────────────

  group('Error response format', () {
    test('errors follow the documented shape', () async {
      final response = await user.createEntity(
        type: 'task',
        name: 'Bad',
        metadata: {'status': 'invalid'},
      );

      expect(response.statusCode, equals(400));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('error'));

      final error = body['error'] as Map<String, dynamic>;
      expect(error, contains('code'));
      expect(error, contains('message'));
      expect(error['code'], isA<String>());
      expect(error['message'], isA<String>());
    });
  });
}
