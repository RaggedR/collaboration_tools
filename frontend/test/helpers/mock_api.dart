import 'package:mocktail/mocktail.dart';
import 'package:collaboration_tools/api/api_client.dart';
import 'package:collaboration_tools/api/models/entity.dart';
import 'package:collaboration_tools/api/models/relationship.dart';
import 'package:collaboration_tools/api/models/schema.dart';
import 'package:collaboration_tools/api/models/graph.dart';
import 'package:collaboration_tools/api/models/auth.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStore extends Mock implements TokenStore {}

/// In-memory token store for testing.
class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Test fixtures for common API responses.
class TestFixtures {
  static final now = DateTime(2026, 3, 20);

  static User testUser({
    String id = 'user-1',
    String email = 'robin@test.com',
    String name = 'Robin',
    bool isAdmin = false,
    String personEntityId = 'person-1',
  }) {
    return User(
      id: id,
      email: email,
      name: name,
      isAdmin: isAdmin,
      personEntityId: personEntityId,
    );
  }

  static User adminUser() => testUser(
        id: 'admin-1',
        email: 'admin@test.com',
        name: 'Admin',
        isAdmin: true,
        personEntityId: 'person-admin',
      );

  static Entity taskEntity({
    String id = 'task-1',
    String name = 'Test Task',
    String status = 'todo',
    String priority = 'medium',
    String? deadline,
  }) {
    return Entity(
      id: id,
      type: 'task',
      name: name,
      metadata: {
        'status': status,
        'priority': priority,
        if (deadline != null) 'deadline': deadline,
      },
      createdBy: 'user-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  static Entity sprintEntity({
    String id = 'sprint-1',
    String name = 'Sprint 1',
    String startDate = '2026-03-01',
    String endDate = '2026-03-14',
    String? goal,
  }) {
    return Entity(
      id: id,
      type: 'sprint',
      name: name,
      metadata: {
        'start_date': startDate,
        'end_date': endDate,
        if (goal != null) 'goal': goal,
      },
      createdBy: 'user-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  static Entity documentEntity({
    String id = 'doc-1',
    String name = 'API Spec',
    String docType = 'spec',
  }) {
    return Entity(
      id: id,
      type: 'document',
      name: name,
      metadata: {'doc_type': docType},
      createdBy: 'user-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  static Entity personEntity({
    String id = 'person-1',
    String name = 'Robin',
    String email = 'robin@test.com',
    String role = 'developer',
  }) {
    return Entity(
      id: id,
      type: 'person',
      name: name,
      metadata: {'email': email, 'role': role},
      createdBy: 'admin-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  static PaginatedEntities paginatedEntities(
    List<Entity> entities, {
    int? total,
    int page = 1,
    int perPage = 50,
  }) {
    return PaginatedEntities(
      entities: entities,
      total: total ?? entities.length,
      page: page,
      perPage: perPage,
    );
  }

  static Schema testSchema() {
    return Schema(
      app: AppConfig(
        name: 'Collaboration Tools',
        description: 'Collaboration tools with kanban and knowledge graph',
        themeColor: '#2563eb',
      ),
      entityTypes: [
        EntityType(
          key: 'task',
          label: 'Task',
          plural: 'Tasks',
          icon: 'check_circle',
          color: '#10b981',
          hidden: false,
          metadataSchema: {
            'type': 'object',
            'properties': {
              'status': {
                'type': 'string',
                'enum': [
                  'backlog', 'todo', 'in_progress', 'review', 'done',
                  'archived'
                ],
              },
              'priority': {
                'type': 'string',
                'enum': ['low', 'medium', 'high', 'urgent'],
              },
            },
          },
        ),
        EntityType(
          key: 'person',
          label: 'Person',
          plural: 'People',
          icon: 'person',
          color: '#ec4899',
          hidden: false,
          metadataSchema: {
            'type': 'object',
            'properties': {
              'email': {'type': 'string'},
              'role': {'type': 'string'},
            },
          },
        ),
      ],
      relTypes: [
        RelType(
          key: 'assigned_to',
          forwardLabel: 'assigned to',
          reverseLabel: 'responsible for',
          sourceTypes: ['task'],
          targetTypes: ['person'],
          symmetric: false,
        ),
      ],
      permissionRules: [
        PermissionRule(
          ruleType: 'admin_only_entity_type',
          entityTypeKey: 'workspace',
        ),
        PermissionRule(
          ruleType: 'edit_granting_rel_type',
          relTypeKey: 'assigned_to',
        ),
      ],
    );
  }
}
