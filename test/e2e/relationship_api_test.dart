@Tags(['e2e'])
import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for relationship CRUD endpoints.
///
/// These verify the HTTP contract for creating, listing, and deleting
/// relationships — including type constraint enforcement, symmetric
/// handling, and proper error responses.
void main() {
  late TestServer server;
  late TestClient admin;
  late TestClient user;

  // Reusable entity IDs created in setUpAll
  late String taskId;
  late String personId;
  late String projectId;

  setUpAll(() async {
    server = TestServer();
    await server.start();

    admin = TestClient(baseUrl: server.baseUrl);
    await admin.register(email: adminEmail, password: adminPassword, name: adminName);

    user = TestClient(baseUrl: server.baseUrl);
    await user.register(email: userEmail, password: userPassword, name: userName);

    // Create reusable entities
    String id(String body) {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      return parsed['entity']?['id'] ?? parsed['id'];
    }

    final taskResp = await user.createEntity(type: 'task', name: 'Fixture Task');
    taskId = id(taskResp.body);

    final personResp = await admin.createEntity(type: 'person', name: 'Fixture Person');
    personId = id(personResp.body);

    final projectResp = await user.createEntity(type: 'project', name: 'Fixture Project');
    projectId = id(projectResp.body);
  });

  tearDownAll(() async {
    admin.dispose();
    user.dispose();
    await server.stop();
  });

  // ── POST /api/relationships ───────────────────────────────

  group('POST /api/relationships', () {
    test('creates a valid relationship', () async {
      final response = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );

      expect(response.statusCode, anyOf(200, 201));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('id'));
      expect(body['rel_type_key'], equals('assigned_to'));
    });

    test('creates containment relationship (project contains task)', () async {
      final response = await user.createRelationship(
        relTypeKey: 'contains_task',
        sourceEntityId: projectId,
        targetEntityId: taskId,
      );

      expect(response.statusCode, anyOf(200, 201));
    });

    test('returns 400 when source type violates constraint', () async {
      // assigned_to requires source: task, but we're using person
      final response = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: personId,
        targetEntityId: personId,
      );

      expect(response.statusCode, equals(400));
    });

    test('returns 400 when target type violates constraint', () async {
      // assigned_to requires target: person, but we're using task
      final anotherTaskResp = await user.createEntity(type: 'task', name: 'T2');
      final anotherTaskId = (jsonDecode(anotherTaskResp.body) as Map)['entity']?['id'] ??
          (jsonDecode(anotherTaskResp.body) as Map)['id'];

      final response = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: anotherTaskId,
      );

      expect(response.statusCode, equals(400));
    });

    test('returns 400 for non-existent rel type', () async {
      final response = await user.createRelationship(
        relTypeKey: 'fantasy_rel',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );

      expect(response.statusCode, equals(400));
    });

    test('returns 404 when source entity does not exist', () async {
      final response = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: '00000000-0000-0000-0000-000000000000',
        targetEntityId: personId,
      );

      expect(response.statusCode, equals(404));
    });

    test('returns 404 when target entity does not exist', () async {
      final response = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: '00000000-0000-0000-0000-000000000000',
      );

      expect(response.statusCode, equals(404));
    });
  });

  // ── Self-referential relationships ────────────────────────

  group('self-referential relationships', () {
    test('task can depend on another task', () async {
      final task2Resp = await user.createEntity(type: 'task', name: 'Prerequisite');
      final task2Id = (jsonDecode(task2Resp.body) as Map)['entity']?['id'] ??
          (jsonDecode(task2Resp.body) as Map)['id'];

      final response = await user.createRelationship(
        relTypeKey: 'depends_on',
        sourceEntityId: taskId,
        targetEntityId: task2Id,
      );

      expect(response.statusCode, anyOf(200, 201));
    });

    test('task can be subtask of another task', () async {
      final parentResp = await user.createEntity(type: 'task', name: 'Parent Task');
      final parentId = (jsonDecode(parentResp.body) as Map)['entity']?['id'] ??
          (jsonDecode(parentResp.body) as Map)['id'];

      final childResp = await user.createEntity(type: 'task', name: 'Child Task');
      final childId = (jsonDecode(childResp.body) as Map)['entity']?['id'] ??
          (jsonDecode(childResp.body) as Map)['id'];

      final response = await user.createRelationship(
        relTypeKey: 'subtask_of',
        sourceEntityId: childId,
        targetEntityId: parentId,
      );

      expect(response.statusCode, anyOf(200, 201));
    });
  });

  // ── Symmetric relationships ───────────────────────────────

  group('symmetric relationships', () {
    test('creates a symmetric collaboration relationship', () async {
      final p1Resp = await admin.createEntity(type: 'person', name: 'Alice');
      final p1Id = (jsonDecode(p1Resp.body) as Map)['entity']?['id'] ??
          (jsonDecode(p1Resp.body) as Map)['id'];

      final p2Resp = await admin.createEntity(type: 'person', name: 'Bob');
      final p2Id = (jsonDecode(p2Resp.body) as Map)['entity']?['id'] ??
          (jsonDecode(p2Resp.body) as Map)['id'];

      final response = await user.createRelationship(
        relTypeKey: 'collaborates',
        sourceEntityId: p1Id,
        targetEntityId: p2Id,
      );

      expect(response.statusCode, anyOf(200, 201));

      // Verify visible from Alice's perspective
      final aliceDetail = await user.getEntity(p1Id);
      final aliceBody = jsonDecode(aliceDetail.body) as Map<String, dynamic>;
      final aliceRels = aliceBody['relationships'] as List;
      final collabFromAlice = aliceRels.where(
        (r) => (r as Map)['rel_type_key'] == 'collaborates',
      );
      expect(collabFromAlice, isNotEmpty);

      // Verify visible from Bob's perspective
      final bobDetail = await user.getEntity(p2Id);
      final bobBody = jsonDecode(bobDetail.body) as Map<String, dynamic>;
      final bobRels = bobBody['relationships'] as List;
      final collabFromBob = bobRels.where(
        (r) => (r as Map)['rel_type_key'] == 'collaborates',
      );
      expect(collabFromBob, isNotEmpty);
    });
  });

  // ── GET /api/relationships ────────────────────────────────

  group('GET /api/relationships', () {
    test('lists relationships for an entity', () async {
      // Ensure at least one relationship exists
      await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );

      final response = await user.listRelationships(entityId: taskId);

      expect(response.statusCode, equals(200));
    });

    test('filters relationships by rel type', () async {
      final response = await user.listRelationships(
        entityId: taskId,
        relType: 'assigned_to',
      );

      expect(response.statusCode, equals(200));
    });
  });

  // ── DELETE /api/relationships/:id ─────────────────────────

  group('DELETE /api/relationships/:id', () {
    test('deletes a relationship without deleting entities', () async {
      final createResp = await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: taskId,
        targetEntityId: personId,
      );
      final relId = (jsonDecode(createResp.body) as Map)['id'];

      final deleteResp = await user.deleteRelationship(relId);

      expect(deleteResp.statusCode, anyOf(200, 204));

      // Both entities still exist
      final taskResp = await user.getEntity(taskId);
      expect(taskResp.statusCode, equals(200));

      final personResp = await user.getEntity(personId);
      expect(personResp.statusCode, equals(200));
    });
  });
}
