@Tags(['e2e'])
import 'dart:convert';
import 'package:test/test.dart';
import '../helpers/test_client.dart';
import '../helpers/test_server.dart';
import '../helpers/fixtures.dart';

/// E2E tests for the graph query endpoint.
///
/// GET /api/graph returns nodes and edges suitable for force-directed
/// graph visualisation (d3, etc.). These tests verify the response
/// shape and filtering behaviour.
void main() {
  late TestServer server;
  late TestClient admin;
  late TestClient user;

  // Pre-created graph: project → task → person
  late String projectId;
  late String taskId;
  late String personId;

  setUpAll(() async {
    server = TestServer();
    await server.start();

    admin = TestClient(baseUrl: server.baseUrl);
    await admin.register(email: adminEmail, password: adminPassword, name: adminName);

    user = TestClient(baseUrl: server.baseUrl);
    await user.register(email: userEmail, password: userPassword, name: userName);

    String id(String body) {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      return parsed['entity']?['id'] ?? parsed['id'];
    }

    // Build a small graph
    final projResp = await user.createEntity(
      type: 'project', name: 'CMS', metadata: {'status': 'active'});
    projectId = id(projResp.body);

    final taskResp = await user.createEntity(
      type: 'task', name: 'Build API', metadata: {'status': 'in_progress'});
    taskId = id(taskResp.body);

    final personResp = await admin.createEntity(
      type: 'person', name: 'Robin', metadata: {'email': 'robin@test.com'});
    personId = id(personResp.body);

    // project → contains_task → task
    await user.createRelationship(
      relTypeKey: 'contains_task',
      sourceEntityId: projectId,
      targetEntityId: taskId,
    );

    // task → assigned_to → person
    await user.createRelationship(
      relTypeKey: 'assigned_to',
      sourceEntityId: taskId,
      targetEntityId: personId,
    );
  });

  tearDownAll(() async {
    admin.dispose();
    user.dispose();
    await server.stop();
  });

  group('GET /api/graph', () {
    test('returns nodes and edges', () async {
      final response = await user.getGraph();

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('nodes'));
      expect(body, contains('edges'));

      final nodes = body['nodes'] as List;
      final edges = body['edges'] as List;

      expect(nodes, isNotEmpty);
      expect(edges, isNotEmpty);
    });

    test('nodes include id, type, name, color, and icon', () async {
      final response = await user.getGraph();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;

      for (final node in nodes) {
        final n = node as Map<String, dynamic>;
        expect(n, contains('id'));
        expect(n, contains('type'));
        expect(n, contains('name'));
        expect(n, contains('color'));
        expect(n, contains('icon'));
      }
    });

    test('edges include id, source, target, rel_type, and label', () async {
      final response = await user.getGraph();
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final edges = body['edges'] as List;

      for (final edge in edges) {
        final e = edge as Map<String, dynamic>;
        expect(e, contains('id'));
        expect(e, contains('source'));
        expect(e, contains('target'));
        expect(e, contains('rel_type'));
        expect(e, contains('label'));
      }
    });

    test('node colors match entity type colors from schema', () async {
      final schemaResp = await user.getSchema();
      final schema = jsonDecode(schemaResp.body) as Map<String, dynamic>;
      final entityTypes = schema['entity_types'] as List;
      final colorMap = {
        for (final et in entityTypes)
          (et as Map)['key'] as String: et['color'] as String,
      };

      final graphResp = await user.getGraph();
      final body = jsonDecode(graphResp.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;

      for (final node in nodes) {
        final n = node as Map<String, dynamic>;
        final expectedColor = colorMap[n['type']];
        expect(n['color'], equals(expectedColor),
            reason: 'Node type ${n['type']} should have color $expectedColor');
      }
    });

    test('traverses from root_id with limited depth', () async {
      // From the project, depth=1 should reach the task but not the person
      final response = await user.getGraph(rootId: projectId, depth: 1);

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;
      final nodeIds = nodes.map((n) => (n as Map)['id']).toSet();

      expect(nodeIds, contains(projectId));
      expect(nodeIds, contains(taskId)); // 1 hop away
      // Person is 2 hops away — should NOT be included at depth=1
      expect(nodeIds, isNot(contains(personId)));
    });

    test('traverses deeper with greater depth', () async {
      // From the project, depth=2 should reach project → task → person
      final response = await user.getGraph(rootId: projectId, depth: 2);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;
      final nodeIds = nodes.map((n) => (n as Map)['id']).toSet();

      expect(nodeIds, contains(projectId));
      expect(nodeIds, contains(taskId));
      expect(nodeIds, contains(personId)); // 2 hops away — now included
    });

    test('filters nodes by entity type', () async {
      final response = await user.getGraph(types: ['task', 'person']);

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;

      // All nodes should be of the requested types
      for (final node in nodes) {
        expect(
          (node as Map)['type'],
          anyOf('task', 'person'),
        );
      }
    });

    test('returns empty graph when no entities exist of requested types', () async {
      final response = await user.getGraph(types: ['document']);

      expect(response.statusCode, equals(200));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = body['nodes'] as List;
      expect(nodes, isEmpty);
    });
  });
}
