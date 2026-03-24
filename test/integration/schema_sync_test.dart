import 'package:test/test.dart';
import 'package:outlier/db/database.dart';
import 'package:outlier/db/schema_queries.dart';
import 'package:outlier/config/schema_loader.dart';
import '../helpers/fixtures.dart';

/// Tests for schema sync behaviour (schema.config → database).
///
/// When the server starts or an admin reloads the schema, the config
/// file is synced into the database. These tests verify that the sync
/// correctly populates the config tables and handles updates.
void main() {
  late Database db;
  late SchemaQueries schemaQueries;

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

    schemaQueries = SchemaQueries(db: db);
  });

  tearDown(() async {
    // Clean all tables between tests (respecting FK order)
    await db.execute('DELETE FROM relationships');
    final hasUsers2 = await db.query("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public')");
    if (hasUsers2.first.toColumnMap()['exists'] == true) {
      await db.execute('UPDATE users SET person_entity_id = NULL');
      await db.execute('DELETE FROM users');
    }
    await db.execute('DELETE FROM entities');
    await db.execute('DELETE FROM permission_rules');
    await db.execute('DELETE FROM rel_types');
    await db.execute('DELETE FROM entity_types');
  });

  tearDownAll(() async {
    await db.close();
  });

  group('Schema sync', () {
    // ── Initial sync ────────────────────────────────────────

    test('syncing the real schema.config populates all entity types', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final entityTypes = await schemaQueries.listEntityTypes();

      expect(entityTypes, hasLength(6));
      final keys = entityTypes.map((et) => et.key).toSet();
      expect(keys, containsAll([
        'workspace', 'project', 'sprint', 'task', 'document', 'person',
      ]));
    });

    test('syncing populates all relationship types', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final relTypes = await schemaQueries.listRelTypes();

      expect(relTypes, hasLength(13));
      final keys = relTypes.map((rt) => rt.key).toSet();
      expect(keys, containsAll([
        'contains_project', 'contains_task', 'contains_doc',
        'owned_by', 'in_sprint', 'assigned_to', 'authored',
        'references', 'depends_on', 'subtask_of', 'collaborates',
      ]));
    });

    test('syncing populates permission rules', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final rules = await schemaQueries.listPermissionRules();

      expect(rules, hasLength(4));
    });

    test('entity type properties are stored correctly', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final taskType = await schemaQueries.getEntityType('task');

      expect(taskType.key, equals('task'));
      expect(taskType.label, equals('Task'));
      expect(taskType.plural, equals('Tasks'));
      expect(taskType.icon, equals('check_circle'));
      expect(taskType.color, equals('#10b981'));
      expect(taskType.hidden, isFalse);
      expect(taskType.metadataSchema, isNotNull);
    });

    test('rel type properties are stored correctly', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final relType = await schemaQueries.getRelType('assigned_to');

      expect(relType.key, equals('assigned_to'));
      expect(relType.forwardLabel, equals('assigned to'));
      expect(relType.reverseLabel, equals('responsible for'));
      expect(relType.sourceTypes, equals(['task']));
      expect(relType.targetTypes, equals(['person']));
      expect(relType.symmetric, isFalse);
    });

    test('symmetric rel type is stored with symmetric flag', () async {
      final config = loadSchemaConfig();
      await SchemaLoader.syncToDatabase(config, db);

      final relType = await schemaQueries.getRelType('collaborates');

      expect(relType.symmetric, isTrue);
      expect(relType.forwardLabel, equals('works with'));
      expect(relType.reverseLabel, equals('works with'));
    });

    // ── Sync is idempotent ──────────────────────────────────

    test('syncing the same config twice produces the same result', () async {
      final config = loadSchemaConfig();

      await SchemaLoader.syncToDatabase(config, db);
      final firstSync = await schemaQueries.listEntityTypes();

      await SchemaLoader.syncToDatabase(config, db);
      final secondSync = await schemaQueries.listEntityTypes();

      expect(secondSync.length, equals(firstSync.length));
      for (var i = 0; i < firstSync.length; i++) {
        expect(secondSync[i].key, equals(firstSync[i].key));
      }
    });

    // ── Sync updates ────────────────────────────────────────

    test('syncing a new config updates entity types', () async {
      // Start with the real config
      await SchemaLoader.syncToDatabase(loadSchemaConfig(), db);

      // Now sync the alternative config (grants, funders)
      await SchemaLoader.syncToDatabase(alternativeValidSchema(), db);

      final entityTypes = await schemaQueries.listEntityTypes();
      final keys = entityTypes.map((et) => et.key).toSet();

      // New types should be present
      expect(keys, contains('grant'));
      expect(keys, contains('funder'));
    });

    test('syncing a new config updates rel types', () async {
      await SchemaLoader.syncToDatabase(loadSchemaConfig(), db);
      await SchemaLoader.syncToDatabase(alternativeValidSchema(), db);

      final relTypes = await schemaQueries.listRelTypes();
      final keys = relTypes.map((rt) => rt.key).toSet();

      expect(keys, contains('funded_by'));
    });

    test('syncing replaces permission rules entirely', () async {
      // Start with rules
      await SchemaLoader.syncToDatabase(loadSchemaConfig(), db);
      final rulesBefore = await schemaQueries.listPermissionRules();
      expect(rulesBefore, hasLength(4));

      // Alternative schema has no permission rules
      await SchemaLoader.syncToDatabase(alternativeValidSchema(), db);
      final rulesAfter = await schemaQueries.listPermissionRules();
      expect(rulesAfter, isEmpty);
    });

    // ── Sync atomicity ──────────────────────────────────────

    test('invalid config does not partially update the database', () async {
      // First, sync a valid config
      await SchemaLoader.syncToDatabase(loadSchemaConfig(), db);
      final before = await schemaQueries.listEntityTypes();

      // Try to sync an invalid config
      final invalidConfig = schemaRelTypeInvalidSourceType();
      expect(
        () => SchemaLoader.syncToDatabase(invalidConfig, db),
        throwsA(anything),
      );

      // Database should still have the previous valid state
      final after = await schemaQueries.listEntityTypes();
      expect(after.length, equals(before.length));
    });
  });
}
