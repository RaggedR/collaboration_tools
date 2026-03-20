import 'package:test/test.dart';
import 'package:outlier/db/database.dart';
import 'package:outlier/db/entity_queries.dart';
import 'package:outlier/db/relationship_queries.dart';
import 'package:outlier/config/schema_loader.dart';
import 'package:outlier/config/schema_cache.dart';
import '../helpers/fixtures.dart';

/// Tests for relationship lifecycle behaviour through the data layer.
///
/// These tests verify that relationships respect type constraints (source/
/// target types), handle symmetric relationships correctly, support
/// directional label resolution, and survive entity deletion cascades.
void main() {
  late Database db;
  late SchemaCache cache;
  late EntityQueries entities;
  late RelationshipQueries relationships;

  const testUserId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  setUpAll(() async {
    db = await Database.connect(testDatabaseUrl);
    await db.migrate();

    final config = loadSchemaConfig();
    await SchemaLoader.syncToDatabase(config, db);

    cache = SchemaCache();
    cache.refresh(config);

    entities = EntityQueries(db: db, cache: cache);
    relationships = RelationshipQueries(db: db, cache: cache);
  });

  tearDown(() async {
    await db.execute('DELETE FROM relationships');
    await db.execute('DELETE FROM entities');
  });

  tearDownAll(() async {
    await db.close();
  });

  // ── Type constraints ──────────────────────────────────────

  group('Type constraints', () {
    test('accepts relationship between valid source and target types', () async {
      final task = await entities.create(
        type: 'task', name: 'Task', metadata: {}, createdBy: testUserId);
      final person = await entities.create(
        type: 'person', name: 'Robin', metadata: {}, createdBy: testUserId);

      final rel = await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      expect(rel.id, isNotEmpty);
      expect(rel.relTypeKey, equals('assigned_to'));
    });

    test('rejects relationship with wrong source type', () async {
      final person1 = await entities.create(
        type: 'person', name: 'Alice', metadata: {}, createdBy: testUserId);
      final person2 = await entities.create(
        type: 'person', name: 'Bob', metadata: {}, createdBy: testUserId);

      // assigned_to: source must be task, not person
      expect(
        () => relationships.create(
          relTypeKey: 'assigned_to',
          sourceEntityId: person1.id,
          targetEntityId: person2.id,
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('rejects relationship with wrong target type', () async {
      final task1 = await entities.create(
        type: 'task', name: 'T1', metadata: {}, createdBy: testUserId);
      final task2 = await entities.create(
        type: 'task', name: 'T2', metadata: {}, createdBy: testUserId);

      // assigned_to: target must be person, not task
      expect(
        () => relationships.create(
          relTypeKey: 'assigned_to',
          sourceEntityId: task1.id,
          targetEntityId: task2.id,
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('rejects relationship with non-existent rel type key', () async {
      final task = await entities.create(
        type: 'task', name: 'T', metadata: {}, createdBy: testUserId);
      final person = await entities.create(
        type: 'person', name: 'P', metadata: {}, createdBy: testUserId);

      expect(
        () => relationships.create(
          relTypeKey: 'fantasy_rel',
          sourceEntityId: task.id,
          targetEntityId: person.id,
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });

    test('rejects relationship to non-existent entity', () async {
      final task = await entities.create(
        type: 'task', name: 'T', metadata: {}, createdBy: testUserId);

      expect(
        () => relationships.create(
          relTypeKey: 'assigned_to',
          sourceEntityId: task.id,
          targetEntityId: '00000000-0000-0000-0000-000000000000',
          createdBy: testUserId,
        ),
        throwsA(anything),
      );
    });
  });

  // ── Self-referential relationships ────────────────────────

  group('Self-referential relationships', () {
    test('task can depend on another task', () async {
      final db_task = await entities.create(
        type: 'task', name: 'Build DB', metadata: {}, createdBy: testUserId);
      final api_task = await entities.create(
        type: 'task', name: 'Build API', metadata: {}, createdBy: testUserId);

      final rel = await relationships.create(
        relTypeKey: 'depends_on',
        sourceEntityId: api_task.id,
        targetEntityId: db_task.id,
        createdBy: testUserId,
      );

      expect(rel.relTypeKey, equals('depends_on'));
    });

    test('task can be subtask of another task', () async {
      final parent = await entities.create(
        type: 'task', name: 'Parent', metadata: {}, createdBy: testUserId);
      final child = await entities.create(
        type: 'task', name: 'Child', metadata: {}, createdBy: testUserId);

      final rel = await relationships.create(
        relTypeKey: 'subtask_of',
        sourceEntityId: child.id,
        targetEntityId: parent.id,
        createdBy: testUserId,
      );

      expect(rel.relTypeKey, equals('subtask_of'));
    });
  });

  // ── Directional labels ────────────────────────────────────

  group('Directional label resolution', () {
    test('forward direction shows forward label', () async {
      final project = await entities.create(
        type: 'project', name: 'CMS', metadata: {}, createdBy: testUserId);
      final task = await entities.create(
        type: 'task', name: 'Build API', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'contains_task',
        sourceEntityId: project.id,
        targetEntityId: task.id,
        createdBy: testUserId,
      );

      // From the project's perspective, this is the forward direction
      final projectDetail = await entities.getWithRelationships(project.id);
      final rel = projectDetail.relationships.first;

      expect(rel.direction, equals('forward'));
      expect(rel.label, equals('contains'));
    });

    test('reverse direction shows reverse label', () async {
      final project = await entities.create(
        type: 'project', name: 'CMS', metadata: {}, createdBy: testUserId);
      final task = await entities.create(
        type: 'task', name: 'Build API', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'contains_task',
        sourceEntityId: project.id,
        targetEntityId: task.id,
        createdBy: testUserId,
      );

      // From the task's perspective, this is the reverse direction
      final taskDetail = await entities.getWithRelationships(task.id);
      final rel = taskDetail.relationships.first;

      expect(rel.direction, equals('reverse'));
      expect(rel.label, equals('belongs to'));
    });

    test('depends_on shows "depends on" forward and "blocks" reverse', () async {
      final blocker = await entities.create(
        type: 'task', name: 'Blocker', metadata: {}, createdBy: testUserId);
      final blocked = await entities.create(
        type: 'task', name: 'Blocked', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'depends_on',
        sourceEntityId: blocked.id,
        targetEntityId: blocker.id,
        createdBy: testUserId,
      );

      final blockedDetail = await entities.getWithRelationships(blocked.id);
      expect(blockedDetail.relationships.first.label, equals('depends on'));

      final blockerDetail = await entities.getWithRelationships(blocker.id);
      expect(blockerDetail.relationships.first.label, equals('blocks'));
    });
  });

  // ── Symmetric relationships ───────────────────────────────

  group('Symmetric relationships', () {
    test('queryable from either direction', () async {
      final alice = await entities.create(
        type: 'person', name: 'Alice', metadata: {}, createdBy: testUserId);
      final bob = await entities.create(
        type: 'person', name: 'Bob', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'collaborates',
        sourceEntityId: alice.id,
        targetEntityId: bob.id,
        createdBy: testUserId,
      );

      // Alice sees the collaboration
      final aliceRels = await relationships.list(
        entityId: alice.id,
        relType: 'collaborates',
      );
      expect(aliceRels, hasLength(1));

      // Bob also sees the same collaboration
      final bobRels = await relationships.list(
        entityId: bob.id,
        relType: 'collaborates',
      );
      expect(bobRels, hasLength(1));
    });

    test('uses the same label from both directions', () async {
      final alice = await entities.create(
        type: 'person', name: 'Alice', metadata: {}, createdBy: testUserId);
      final bob = await entities.create(
        type: 'person', name: 'Bob', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'collaborates',
        sourceEntityId: alice.id,
        targetEntityId: bob.id,
        createdBy: testUserId,
      );

      final aliceDetail = await entities.getWithRelationships(alice.id);
      final bobDetail = await entities.getWithRelationships(bob.id);

      // Both should see "works with"
      expect(aliceDetail.relationships.first.label, equals('works with'));
      expect(bobDetail.relationships.first.label, equals('works with'));
    });

    test('creating symmetric relationship once does not create a duplicate', () async {
      final alice = await entities.create(
        type: 'person', name: 'Alice', metadata: {}, createdBy: testUserId);
      final bob = await entities.create(
        type: 'person', name: 'Bob', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'collaborates',
        sourceEntityId: alice.id,
        targetEntityId: bob.id,
        createdBy: testUserId,
      );

      // There should be exactly one relationship row, visible from both sides
      final allRels = await relationships.list(relType: 'collaborates');
      expect(allRels, hasLength(1));
    });
  });

  // ── Relationship listing and filtering ────────────────────

  group('Listing and filtering', () {
    test('lists relationships by entity ID', () async {
      final task = await entities.create(
        type: 'task', name: 'T', metadata: {}, createdBy: testUserId);
      final person1 = await entities.create(
        type: 'person', name: 'P1', metadata: {}, createdBy: testUserId);
      final person2 = await entities.create(
        type: 'person', name: 'P2', metadata: {}, createdBy: testUserId);
      // Just for a different entity
      final project = await entities.create(
        type: 'project', name: 'Proj', metadata: {}, createdBy: testUserId);

      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id, targetEntityId: person1.id,
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id, targetEntityId: person2.id,
        createdBy: testUserId,
      );
      await relationships.create(
        relTypeKey: 'contains_task',
        sourceEntityId: project.id, targetEntityId: task.id,
        createdBy: testUserId,
      );

      // Task is involved in 3 relationships (2 assigned_to + 1 contains_task)
      final taskRels = await relationships.list(entityId: task.id);
      expect(taskRels, hasLength(3));

      // Filter by rel type
      final assignedRels = await relationships.list(
        entityId: task.id,
        relType: 'assigned_to',
      );
      expect(assignedRels, hasLength(2));
    });
  });

  // ── Deletion ──────────────────────────────────────────────

  group('Relationship deletion', () {
    test('deleting a relationship does not delete the entities', () async {
      final task = await entities.create(
        type: 'task', name: 'T', metadata: {}, createdBy: testUserId);
      final person = await entities.create(
        type: 'person', name: 'P', metadata: {}, createdBy: testUserId);

      final rel = await relationships.create(
        relTypeKey: 'assigned_to',
        sourceEntityId: task.id,
        targetEntityId: person.id,
        createdBy: testUserId,
      );

      await relationships.delete(rel.id);

      // Both entities still exist
      expect((await entities.get(task.id)).name, equals('T'));
      expect((await entities.get(person.id)).name, equals('P'));

      // Relationship is gone
      final rels = await relationships.list(entityId: task.id);
      expect(rels, isEmpty);
    });
  });
}
