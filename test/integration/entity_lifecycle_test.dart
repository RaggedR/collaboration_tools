import 'package:test/test.dart';
import 'package:outlier/db/database.dart';
import 'package:outlier/db/entity_queries.dart';
import 'package:outlier/db/relationship_queries.dart';
import 'package:outlier/config/schema_loader.dart';
import 'package:outlier/config/schema_cache.dart';
import '../helpers/fixtures.dart';

/// Tests for entity lifecycle behaviour through the data layer.
///
/// These tests hit a real PostgreSQL database to verify that entity
/// CRUD operations work correctly with actual data persistence,
/// metadata validation, auto-relationships, and cascading deletes.
void main() {
  late Database db;
  late SchemaCache cache;
  late EntityQueries entities;
  late RelationshipQueries relationships;

  // Stable test user UUID (would be created via auth in real setup)
  const testUserId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  setUpAll(() async {
    db = await Database.connect(testDatabaseUrl);
    await db.migrate();

    // Clean stale data from prior runs
    await db.execute('DELETE FROM relationships');
    final hasUsers = await db.query("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public')");
    if (hasUsers.first.toColumnMap()['exists'] == true) {
      await db.execute('UPDATE users SET person_entity_id = NULL');
      await db.execute('DELETE FROM users');
    }
    await db.execute('DELETE FROM entities');

    final config = loadSchemaConfig();
    await SchemaLoader.syncToDatabase(config, db);

    cache = SchemaCache();
    cache.refresh(config);

    entities = EntityQueries(db: db, cache: cache);
    relationships = RelationshipQueries(db: db, cache: cache);
  });

  tearDown(() async {
    await db.execute('DELETE FROM relationships');
    final hasUsers = await db.query("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public')");
    if (hasUsers.first.toColumnMap()['exists'] == true) {
      await db.execute('UPDATE users SET person_entity_id = NULL');
    }
    await db.execute('DELETE FROM entities');
  });

  tearDownAll(() async {
    await db.close();
  });

  group('Entity creation', () {
    test('creates an entity with a UUID and timestamps', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Write tests',
        metadata: {'status': 'backlog', 'priority': 'high'},
        createdBy: testUserId,
      );

      expect(entity.id, isNotEmpty);
      expect(entity.type, equals('task'));
      expect(entity.name, equals('Write tests'));
      expect(entity.metadata['status'], equals('backlog'));
      expect(entity.metadata['priority'], equals('high'));
      expect(entity.createdBy, equals(testUserId));
      expect(entity.createdAt, isNotNull);
      expect(entity.updatedAt, isNotNull);
    });

    test('rejects entity with unknown type', () async {
      expect(
        () => entities.create(
          type: 'unicorn',
          name: 'Not a real type',
          metadata: {},
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('rejects entity with invalid metadata', () async {
      expect(
        () => entities.create(
          type: 'task',
          name: 'Bad metadata',
          metadata: {'status': 'nonexistent_status'},
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('accepts entity with empty metadata when no fields are required', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Bare task',
        metadata: {},
        createdBy: testUserId,
      );

      expect(entity.name, equals('Bare task'));
      expect(entity.metadata, equals({}));
    });

    test('rejects sprint without required start_date and end_date', () async {
      expect(
        () => entities.create(
          type: 'sprint',
          name: 'Missing dates',
          metadata: {'goal': 'Ship v1'},
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('accepts sprint with required fields', () async {
      final sprint = await entities.create(
        type: 'sprint',
        name: 'Sprint 1',
        metadata: {
          'start_date': '2026-03-20',
          'end_date': '2026-04-03',
          'goal': 'Ship v1',
        },
        createdBy: testUserId,
      );

      expect(sprint.type, equals('sprint'));
      expect(sprint.metadata['start_date'], equals('2026-03-20'));
    });
  });

  group('Entity reading', () {
    test('retrieves entity by ID', () async {
      final created = await entities.create(
        type: 'project',
        name: 'Outlier',
        metadata: {'status': 'active'},
        createdBy: testUserId,
      );

      final retrieved = await entities.get(created.id);

      expect(retrieved.id, equals(created.id));
      expect(retrieved.name, equals('Outlier'));
      expect(retrieved.metadata['status'], equals('active'));
    });

    test('retrieves entity with its relationships', () async {
      final project = await entities.create(
        type: 'project',
        name: 'Outlier',
        metadata: {'status': 'active'},
        createdBy: testUserId,
      );
      final task = await entities.create(
        type: 'task',
        name: 'Build API',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'contains_task',
        sourceEntityId: project.id,
        targetEntityId: task.id,
        createdBy: testUserId,
      );

      final result = await entities.getWithRelationships(project.id);

      expect(result.entity.name, equals('Outlier'));
      expect(result.relationships, hasLength(1));
      expect(result.relationships.first.relTypeKey, equals('contains_task'));
      expect(result.relationships.first.relatedEntity.name, equals('Build API'));
    });

    test('returns not-found for non-existent entity ID', () async {
      expect(
        () => entities.get('00000000-0000-0000-0000-000000000000'),
        throwsA(anything),
      );
    });
  });

  group('Entity updating', () {
    test('updates name and metadata', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Original name',
        metadata: {'status': 'backlog'},
        createdBy: testUserId,
      );

      final updated = await entities.update(
        entity.id,
        name: 'Updated name',
        metadata: {'status': 'in_progress'},
      );

      expect(updated.name, equals('Updated name'));
      expect(updated.metadata['status'], equals('in_progress'));
    });

    test('updates the updated_at timestamp', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Timestamp test',
        metadata: {},
        createdBy: testUserId,
      );

      // Small delay to ensure timestamp differs
      await Future.delayed(Duration(milliseconds: 10));

      final updated = await entities.update(
        entity.id,
        metadata: {'status': 'done'},
      );

      expect(updated.updatedAt.isAfter(entity.updatedAt), isTrue);
    });

    test('rejects update with invalid metadata', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Will fail update',
        metadata: {'status': 'backlog'},
        createdBy: testUserId,
      );

      expect(
        () => entities.update(
          entity.id,
          metadata: {'status': 'invalid_value'},
        ),
        throwsA(anything),
      );
    });

    test('update preserves the entity type (type is immutable)', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Type is fixed',
        metadata: {},
        createdBy: testUserId,
      );

      final updated = await entities.update(
        entity.id,
        name: 'New name',
      );

      expect(updated.type, equals('task'));
    });
  });

  group('Entity deletion', () {
    test('deletes the entity', () async {
      final entity = await entities.create(
        type: 'task',
        name: 'Delete me',
        metadata: {},
        createdBy: testUserId,
      );

      await entities.delete(entity.id);

      expect(
        () => entities.get(entity.id),
        throwsA(anything),
      );
    });

    test('cascades to delete all relationships involving the entity', () async {
      final task = await entities.create(
        type: 'task',
        name: 'Will be deleted',
        metadata: {},
        createdBy: testUserId,
      );
      final person = await entities.create(
        type: 'person',
        name: 'Still here',
        metadata: {},
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      await entities.delete(task.id);

      // Relationship is gone
      final rels = await relationships.list(entityId: person.id);
      expect(rels, isEmpty);

      // Person still exists
      final personStillExists = await entities.get(person.id);
      expect(personStillExists.name, equals('Still here'));
    });
  });

  group('Entity listing', () {
    test('lists entities filtered by type', () async {
      await entities.create(type: 'task', name: 'Task 1', metadata: {}, createdBy: testUserId);
      await entities.create(type: 'task', name: 'Task 2', metadata: {}, createdBy: testUserId);
      await entities.create(type: 'project', name: 'Project 1', metadata: {}, createdBy: testUserId);

      final tasks = await entities.list(type: 'task');

      expect(tasks.entities, hasLength(2));
      expect(tasks.entities.every((e) => e.type == 'task'), isTrue);
    });

    test('searches entities by name (partial, case-insensitive)', () async {
      await entities.create(type: 'task', name: 'Build login page', metadata: {}, createdBy: testUserId);
      await entities.create(type: 'task', name: 'Fix logout bug', metadata: {}, createdBy: testUserId);
      await entities.create(type: 'task', name: 'Write docs', metadata: {}, createdBy: testUserId);

      final results = await entities.list(search: 'log');

      expect(results.entities, hasLength(2)); // "login" and "logout"
    });

    test('filters entities by metadata field', () async {
      await entities.create(type: 'task', name: 'Done 1', metadata: {'status': 'done'}, createdBy: testUserId);
      await entities.create(type: 'task', name: 'Todo 1', metadata: {'status': 'todo'}, createdBy: testUserId);
      await entities.create(type: 'task', name: 'Done 2', metadata: {'status': 'done'}, createdBy: testUserId);

      final results = await entities.list(
        type: 'task',
        metadata: {'status': 'done'},
      );

      expect(results.entities, hasLength(2));
      expect(results.entities.every((e) => e.metadata['status'] == 'done'), isTrue);
    });

    test('returns paginated results with total count', () async {
      for (var i = 0; i < 10; i++) {
        await entities.create(type: 'task', name: 'Task $i', metadata: {}, createdBy: testUserId);
      }

      final page1 = await entities.list(type: 'task', page: 1, perPage: 3);

      expect(page1.entities, hasLength(3));
      expect(page1.total, equals(10));

      final page4 = await entities.list(type: 'task', page: 4, perPage: 3);
      expect(page4.entities, hasLength(1)); // items 9 (0-indexed)
    });

    test('returns empty list for type with no entities', () async {
      final results = await entities.list(type: 'document');

      expect(results.entities, isEmpty);
      expect(results.total, equals(0));
    });
  });

  group('Auto-relationships', () {
    test('creating a sprint auto-creates owned_by relationship to current user', () async {
      // The current user needs a person entity to link to.
      // How the system resolves current_user → person entity is implementation detail,
      // but the observable behaviour is: sprint gets an owned_by relationship.
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {'email': 'robin@test.com'},
        createdBy: testUserId,
      );

      final sprint = await entities.create(
        type: 'sprint',
        name: 'Sprint 1',
        metadata: {'start_date': '2026-03-20', 'end_date': '2026-04-03'},
        createdBy: testUserId,
      );

      final result = await entities.getWithRelationships(sprint.id);
      final ownerRels = result.relationships
          .where((r) => r.relTypeKey == 'owned_by')
          .toList();

      expect(ownerRels, hasLength(1));
      expect(ownerRels.first.relatedEntity.type, equals('person'));
    });

    test('auto-relationship does not fire for entity types without a rule', () async {
      final task = await entities.create(
        type: 'task',
        name: 'No auto-rel expected',
        metadata: {},
        createdBy: testUserId,
      );

      final result = await entities.getWithRelationships(task.id);

      // Task has no auto-relationship rule in schema.config
      expect(result.relationships, isEmpty);
    });
  });
}
