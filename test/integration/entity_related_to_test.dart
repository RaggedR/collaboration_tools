import 'package:test/test.dart';
import 'package:outlier/db/database.dart';
import 'package:outlier/db/entity_queries.dart';
import 'package:outlier/db/relationship_queries.dart';
import 'package:outlier/config/schema_loader.dart';
import 'package:outlier/config/schema_cache.dart';
import '../helpers/fixtures.dart';

/// Integration tests for the `related_to` entity list filter.
///
/// These test EntityQueries.list() with the new `relatedTo` and `relType`
/// parameters directly against a real PostgreSQL database. They verify
/// that the JOIN-based filtering returns the correct entities based on
/// their relationships.
void main() {
  late Database db;
  late SchemaCache cache;
  late EntityQueries entities;
  late RelationshipQueries relationships;

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

  group('Entity listing with related_to filter', () {
    test('returns tasks assigned to a specific person', () async {
      // Setup: person, 3 tasks, 2 assigned to person
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {'email': 'robin@test.com'},
        createdBy: testUserId,
      );

      final task1 = await entities.create(
        type: 'task',
        name: 'Assigned task 1',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );
      final task2 = await entities.create(
        type: 'task',
        name: 'Assigned task 2',
        metadata: {'status': 'in_progress'},
        createdBy: testUserId,
      );
      final task3 = await entities.create(
        type: 'task',
        name: 'Unassigned task',
        metadata: {'status': 'backlog'},
        createdBy: testUserId,
      );

      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task1.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task2.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      // Act: list tasks related to person via assigned_to
      final result = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
      );

      // Assert: only the 2 assigned tasks
      expect(result.entities, hasLength(2));
      expect(result.total, equals(2));
      final names = result.entities.map((e) => e.name).toSet();
      expect(names, containsAll(['Assigned task 1', 'Assigned task 2']));
      expect(names, isNot(contains('Unassigned task')));
    });

    test('returns sprints owned by a specific person', () async {
      // Use a different userId so auto-relationships don't link sprints to Sarah
      const otherUserId = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
      final person = await entities.create(
        type: 'person',
        name: 'Sarah',
        metadata: {},
        createdBy: otherUserId,
      );

      final sprint1 = await entities.create(
        type: 'sprint',
        name: 'Sprint 1',
        metadata: {'start_date': '2026-03-01', 'end_date': '2026-03-14'},
        createdBy: testUserId,
      );
      final sprint2 = await entities.create(
        type: 'sprint',
        name: 'Sprint 2',
        metadata: {'start_date': '2026-03-15', 'end_date': '2026-03-28'},
        createdBy: testUserId,
      );

      // owned_by: sprint → person
      await relationships.create(
        relTypeKey: 'owned_by',
        sourceEntityId: sprint1.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      final result = await entities.list(
        type: 'sprint',
        relatedTo: person.id,
        relType: 'owned_by',
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('Sprint 1'));
    });

    test('returns documents authored by a specific person', () async {
      // Use a different userId so auto-relationships don't link docs to Robin
      const otherUserId = 'cccccccc-dddd-eeee-ffff-000000000000';
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdBy: otherUserId,
      );

      final doc1 = await entities.create(
        type: 'document',
        name: 'API Spec',
        metadata: {'doc_type': 'spec'},
        createdBy: testUserId,
      );
      final doc2 = await entities.create(
        type: 'document',
        name: 'Meeting notes',
        metadata: {'doc_type': 'note'},
        createdBy: testUserId,
      );

      // authored: person → document
      await relationships.create(
        relTypeKey: 'authored',
        sourceEntityId: person.id,
        targetEntityId: doc1.id,
        createdBy: testUserId,
      );

      final result = await entities.list(
        type: 'document',
        relatedTo: person.id,
        relType: 'authored',
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('API Spec'));
    });

    test('returns tasks in a specific sprint', () async {
      final sprint = await entities.create(
        type: 'sprint',
        name: 'Sprint 5',
        metadata: {'start_date': '2026-03-01', 'end_date': '2026-03-14'},
        createdBy: testUserId,
      );

      final task1 = await entities.create(
        type: 'task',
        name: 'In sprint',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );
      final task2 = await entities.create(
        type: 'task',
        name: 'Not in sprint',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );

      // in_sprint: task → sprint
      await relationships.create(
        relTypeKey: 'in_sprint',
        sourceEntityId: task1.id,
        targetEntityId: sprint.id,
        createdBy: testUserId,
      );

      final result = await entities.list(
        type: 'task',
        relatedTo: sprint.id,
        relType: 'in_sprint',
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('In sprint'));
    });

    test('returns tasks in a specific project (reverse relationship)', () async {
      final project = await entities.create(
        type: 'project',
        name: 'CMS Project',
        metadata: {'status': 'active'},
        createdBy: testUserId,
      );

      final task1 = await entities.create(
        type: 'task',
        name: 'Project task',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );
      final task2 = await entities.create(
        type: 'task',
        name: 'Orphan task',
        metadata: {'status': 'todo'},
        createdBy: testUserId,
      );

      // contains_task: project → task
      await relationships.create(
        relTypeKey: 'contains_task',
        sourceEntityId: project.id,
        targetEntityId: task1.id,
        createdBy: testUserId,
      );

      final result = await entities.list(
        type: 'task',
        relatedTo: project.id,
        relType: 'contains_task',
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('Project task'));
    });

    test('combines related_to with metadata filter', () async {
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdBy: testUserId,
      );

      final task1 = await entities.create(
        type: 'task',
        name: 'High priority',
        metadata: {'status': 'todo', 'priority': 'high'},
        createdBy: testUserId,
      );
      final task2 = await entities.create(
        type: 'task',
        name: 'Low priority',
        metadata: {'status': 'todo', 'priority': 'low'},
        createdBy: testUserId,
      );

      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task1.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task2.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      // Filter: tasks assigned to person AND priority = high
      final result = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
        metadata: {'priority': 'high'},
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('High priority'));
    });

    test('combines related_to with search', () async {
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdBy: testUserId,
      );

      final task1 = await entities.create(
        type: 'task',
        name: 'Build login page',
        metadata: {},
        createdBy: testUserId,
      );
      final task2 = await entities.create(
        type: 'task',
        name: 'Fix dashboard bug',
        metadata: {},
        createdBy: testUserId,
      );

      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task1.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task2.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      // Search "login" within person's assigned tasks
      final result = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
        search: 'login',
      );

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('Build login page'));
    });

    test('pagination works with related_to filter', () async {
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdBy: testUserId,
      );

      // Create 5 tasks assigned to person
      for (var i = 0; i < 5; i++) {
        final task = await entities.create(
          type: 'task',
          name: 'Task $i',
          metadata: {},
          createdBy: testUserId,
        );
        await relationships.create(
          relTypeKey: 'assigned_to',
          sourceEntityId: task.id,
          targetEntityId: person.id,
          createdBy: testUserId,
        );
      }

      final page1 = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
        page: 1,
        perPage: 2,
      );

      expect(page1.entities, hasLength(2));
      expect(page1.total, equals(5));

      final page3 = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
        page: 3,
        perPage: 2,
      );

      expect(page3.entities, hasLength(1));
    });

    test('returns empty when entity has no relationships of given type', () async {
      final person = await entities.create(
        type: 'person',
        name: 'Lonely',
        metadata: {},
        createdBy: testUserId,
      );

      final result = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
      );

      expect(result.entities, isEmpty);
      expect(result.total, equals(0));
    });

    test('does not return duplicate entities when multiple rels exist', () async {
      final person = await entities.create(
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdBy: testUserId,
      );

      final task = await entities.create(
        type: 'task',
        name: 'Multi-rel task',
        metadata: {},
        createdBy: testUserId,
      );

      // Two different relationships from task to person
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      // Only one result even though there's a relationship
      final result = await entities.list(
        type: 'task',
        relatedTo: person.id,
        relType: 'assigned_to',
      );

      expect(result.entities, hasLength(1));
    });
  });
}
