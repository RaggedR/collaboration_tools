@Tags(['e2e'])
import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for the `related_to` query parameter on GET /api/entities.
///
/// These test the full HTTP round-trip: create entities, create relationships,
/// then list entities filtered by relationship. They verify the `related_to`
/// and `rel_type` query parameters work through the full stack.
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

  String entityId(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    return body['entity']?['id'] ?? body['id'];
  }

  group('GET /api/entities with related_to filter', () {
    late String personId;
    late String task1Id;
    late String task2Id;
    late String task3Id;

    setUp(() async {
      // Create a person (admin-only)
      final personResp = await admin.createEntity(
        type: 'person',
        name: 'Filter Test Person',
        metadata: {'email': 'filter@test.com', 'role': 'tester'},
      );
      personId = entityId(personResp.body);

      // Create 3 tasks
      final t1 = await user.createEntity(
        type: 'task',
        name: 'Assigned task A',
        metadata: {'status': 'todo', 'priority': 'high'},
      );
      task1Id = entityId(t1.body);

      final t2 = await user.createEntity(
        type: 'task',
        name: 'Assigned task B',
        metadata: {'status': 'in_progress', 'priority': 'low'},
      );
      task2Id = entityId(t2.body);

      final t3 = await user.createEntity(
        type: 'task',
        name: 'Unrelated task C',
        metadata: {'status': 'backlog'},
      );
      task3Id = entityId(t3.body);

      // Assign tasks A and B to the person
      await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: task1Id,
        targetEntityId: personId,
      );
      await user.createRelationship(
        relTypeKey: 'assigned_to',
        sourceEntityId: task2Id,
        targetEntityId: personId,
      );
    });

    test('filters tasks by assigned_to relationship', () async {
      final response = await user.listEntities(
        type: 'task',
        relatedTo: personId,
        relType: 'assigned_to',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;

      expect(entities, hasLength(2));
      final names = entities.map((e) => (e as Map)['name']).toSet();
      expect(names, containsAll(['Assigned task A', 'Assigned task B']));
      expect(names, isNot(contains('Unrelated task C')));
    });

    test('returns correct total count with related_to filter', () async {
      final response = await user.listEntities(
        type: 'task',
        relatedTo: personId,
        relType: 'assigned_to',
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['total'], equals(2));
    });

    test('combines related_to with metadata filter', () async {
      final response = await user.listEntities(
        type: 'task',
        relatedTo: personId,
        relType: 'assigned_to',
        metadata: {'priority': 'high'},
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;

      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('Assigned task A'));
    });

    test('combines related_to with search', () async {
      final response = await user.listEntities(
        type: 'task',
        relatedTo: personId,
        relType: 'assigned_to',
        search: 'task B',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;

      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('Assigned task B'));
    });

    test('returns empty list when no relationships match', () async {
      // Create a person with no assigned tasks
      final lonelyResp = await admin.createEntity(
        type: 'person',
        name: 'No Tasks Person',
        metadata: {'email': 'lonely@test.com'},
      );
      final lonelyId = entityId(lonelyResp.body);

      final response = await user.listEntities(
        type: 'task',
        relatedTo: lonelyId,
        relType: 'assigned_to',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['entities'], isEmpty);
      expect(body['total'], equals(0));
    });

    test('pagination works with related_to filter', () async {
      // Create extra tasks assigned to person
      for (var i = 0; i < 3; i++) {
        final t = await user.createEntity(
          type: 'task',
          name: 'Paginated task $i',
          metadata: {'status': 'todo'},
        );
        await user.createRelationship(
          relTypeKey: 'assigned_to',
          sourceEntityId: entityId(t.body),
          targetEntityId: personId,
        );
      }

      // Now 5 tasks assigned (2 from setup + 3 new)
      final response = await user.listEntities(
        type: 'task',
        relatedTo: personId,
        relType: 'assigned_to',
        page: 1,
        perPage: 2,
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect((body['entities'] as List), hasLength(2));
      expect(body['total'], equals(5));
    });
  });

  group('GET /api/entities with related_to for sprints and documents', () {
    test('filters sprints by owned_by relationship', () async {
      final personResp = await admin.createEntity(
        type: 'person',
        name: 'Sprint Owner',
        metadata: {'email': 'owner@test.com'},
      );
      final personId = entityId(personResp.body);

      final s1 = await user.createEntity(
        type: 'sprint',
        name: 'Owned Sprint',
        metadata: {'start_date': '2026-03-01', 'end_date': '2026-03-14'},
      );
      final s2 = await user.createEntity(
        type: 'sprint',
        name: 'Other Sprint',
        metadata: {'start_date': '2026-04-01', 'end_date': '2026-04-14'},
      );

      await user.createRelationship(
        relTypeKey: 'owned_by',
        sourceEntityId: entityId(s1.body),
        targetEntityId: personId,
      );

      final response = await user.listEntities(
        type: 'sprint',
        relatedTo: personId,
        relType: 'owned_by',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('Owned Sprint'));
    });

    test('filters documents by authored relationship', () async {
      final personResp = await admin.createEntity(
        type: 'person',
        name: 'Doc Author',
        metadata: {'email': 'author@test.com'},
      );
      final personId = entityId(personResp.body);

      final d1 = await user.createEntity(
        type: 'document',
        name: 'My Spec',
        metadata: {'doc_type': 'spec'},
      );
      final d2 = await user.createEntity(
        type: 'document',
        name: 'Other Doc',
        metadata: {'doc_type': 'note'},
      );

      // authored: person → document
      await user.createRelationship(
        relTypeKey: 'authored',
        sourceEntityId: personId,
        targetEntityId: entityId(d1.body),
      );

      final response = await user.listEntities(
        type: 'document',
        relatedTo: personId,
        relType: 'authored',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('My Spec'));
    });

    test('filters tasks by in_sprint relationship', () async {
      final sprintResp = await user.createEntity(
        type: 'sprint',
        name: 'Sprint X',
        metadata: {'start_date': '2026-03-01', 'end_date': '2026-03-14'},
      );
      final sprintId = entityId(sprintResp.body);

      final t1 = await user.createEntity(
        type: 'task',
        name: 'Sprint task',
        metadata: {'status': 'todo'},
      );
      await user.createEntity(
        type: 'task',
        name: 'No sprint task',
        metadata: {'status': 'todo'},
      );

      await user.createRelationship(
        relTypeKey: 'in_sprint',
        sourceEntityId: entityId(t1.body),
        targetEntityId: sprintId,
      );

      final response = await user.listEntities(
        type: 'task',
        relatedTo: sprintId,
        relType: 'in_sprint',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('Sprint task'));
    });

    test('filters tasks by contains_task (project relationship)', () async {
      final projResp = await user.createEntity(
        type: 'project',
        name: 'CMS Project',
        metadata: {'status': 'active'},
      );
      final projectId = entityId(projResp.body);

      final t1 = await user.createEntity(
        type: 'task',
        name: 'Project task',
        metadata: {'status': 'todo'},
      );

      // contains_task: project → task
      await user.createRelationship(
        relTypeKey: 'contains_task',
        sourceEntityId: projectId,
        targetEntityId: entityId(t1.body),
      );

      final response = await user.listEntities(
        type: 'task',
        relatedTo: projectId,
        relType: 'contains_task',
      );

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = body['entities'] as List;
      expect(entities, hasLength(1));
      expect((entities.first as Map)['name'], equals('Project task'));
    });
  });
}
