import 'package:test/test.dart';
import 'package:outlier/config/schema_loader.dart';
import '../helpers/fixtures.dart';

/// Tests for schema.config validation.
///
/// The SchemaLoader is responsible for parsing a JSON config and reporting
/// whether it's valid. These tests verify the validation rules — they don't
/// test how the config is stored or applied, just whether it's accepted or
/// rejected with appropriate errors.
void main() {
  group('Schema validation', () {
    // ── Valid schemas ─────────────────────────────────────────

    group('accepts valid schemas', () {
      test('accepts the real schema.config from the project', () {
        final config = loadSchemaConfig();
        final result = SchemaLoader.validate(config);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('accepts a minimal valid schema', () {
        final result = SchemaLoader.validate(minimalValidSchema());

        expect(result.isValid, isTrue);
      });

      test('accepts a schema with multiple entity types and relationships', () {
        final result = SchemaLoader.validate(alternativeValidSchema());

        expect(result.isValid, isTrue);
      });
    });

    // ── Required top-level sections ───────────────────────────

    group('requires top-level sections', () {
      test('rejects schema without app section', () {
        final result = SchemaLoader.validate(schemaMissingApp());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('app')));
      });

      test('rejects schema without entity_types', () {
        final result = SchemaLoader.validate(schemaMissingEntityTypes());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('entity_types')));
      });
    });

    // ── Entity type validation ────────────────────────────────

    group('validates entity type definitions', () {
      test('rejects entity type missing required key field', () {
        final result = SchemaLoader.validate(schemaEntityTypeMissingKey());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('key')));
      });

      test('rejects duplicate entity type keys', () {
        final result = SchemaLoader.validate(schemaDuplicateEntityKeys());

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          anyElement(allOf(contains('duplicate'), contains('thing'))),
        );
      });

      test('accepts entity type without metadata_schema (schema is optional)', () {
        final schema = minimalValidSchema();
        (schema['entity_types'] as List).first.remove('metadata_schema');

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isTrue);
      });
    });

    // ── Relationship type validation ──────────────────────────

    group('validates relationship type definitions', () {
      test('rejects rel type whose source_types reference unknown entity type', () {
        final result = SchemaLoader.validate(schemaRelTypeInvalidSourceType());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('nonexistent_type')));
      });

      test('rejects rel type whose target_types reference unknown entity type', () {
        final result = SchemaLoader.validate(schemaRelTypeInvalidTargetType());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('ghost')));
      });

      test('rejects duplicate relationship type keys', () {
        final result = SchemaLoader.validate(schemaDuplicateRelKeys());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('dup')));
      });

      test('accepts self-referential rel types (source and target same type)', () {
        final schema = minimalValidSchema();
        schema['rel_types'] = [
          {
            'key': 'links_to',
            'forward_label': 'links to',
            'reverse_label': 'linked from',
            'source_types': ['thing'],
            'target_types': ['thing'],
            'symmetric': false,
          },
        ];

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isTrue);
      });

      test('accepts symmetric relationship types', () {
        final schema = minimalValidSchema();
        schema['rel_types'] = [
          {
            'key': 'related_to',
            'forward_label': 'related to',
            'reverse_label': 'related to',
            'source_types': ['thing'],
            'target_types': ['thing'],
            'symmetric': true,
          },
        ];

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isTrue);
      });
    });

    // ── Permission rule validation ────────────────────────────

    group('validates permission rules', () {
      test('rejects admin_only_entity_type referencing unknown entity type', () {
        final result =
            SchemaLoader.validate(schemaPermissionInvalidEntityType());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('ghost')));
      });

      test('rejects edit_granting_rel_type referencing unknown rel type', () {
        final result = SchemaLoader.validate(schemaPermissionInvalidRelType());

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('phantom')));
      });

      test('accepts valid permission rules', () {
        final schema = minimalValidSchema();
        schema['rel_types'] = [
          {
            'key': 'owns',
            'forward_label': 'owns',
            'reverse_label': 'owned by',
            'source_types': ['thing'],
            'target_types': ['thing'],
            'symmetric': false,
          },
        ];
        schema['permission_rules'] = [
          {'rule_type': 'admin_only_entity_type', 'entity_type_key': 'thing'},
          {'rule_type': 'edit_granting_rel_type', 'rel_type_key': 'owns'},
        ];

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isTrue);
      });
    });

    // ── Auto-relationship validation ──────────────────────────

    group('validates auto-relationships', () {
      test('rejects auto-relationship referencing unknown rel type', () {
        final result = SchemaLoader.validate(schemaAutoRelInvalidRelType());

        expect(result.isValid, isFalse);
      });

      test('rejects auto-relationship referencing unknown entity type', () {
        final result = SchemaLoader.validate(schemaAutoRelInvalidEntityType());

        expect(result.isValid, isFalse);
      });

      test('accepts valid auto-relationship', () {
        final schema = minimalValidSchema();
        // Need a person type and a rel type for the auto-relationship to reference
        (schema['entity_types'] as List).add({
          'key': 'person',
          'label': 'Person',
          'plural': 'People',
          'icon': 'person',
          'color': '#ec4899',
          'hidden': false,
        });
        schema['rel_types'] = [
          {
            'key': 'created_by',
            'forward_label': 'created by',
            'reverse_label': 'created',
            'source_types': ['thing'],
            'target_types': ['person'],
            'symmetric': false,
          },
        ];
        schema['auto_relationships'] = [
          {
            'trigger': 'create',
            'entity_type': 'thing',
            'rel_type_key': 'created_by',
            'target': 'current_user',
          },
        ];

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isTrue);
      });
    });

    // ── Cross-reference integrity ─────────────────────────────

    group('validates cross-reference integrity', () {
      test('reports all errors at once, not just the first', () {
        final schema = minimalValidSchema();
        schema['rel_types'] = [
          {
            'key': 'bad1',
            'forward_label': 'a',
            'reverse_label': 'b',
            'source_types': ['ghost1'],
            'target_types': ['ghost2'],
            'symmetric': false,
          },
        ];
        schema['permission_rules'] = [
          {'rule_type': 'admin_only_entity_type', 'entity_type_key': 'ghost3'},
        ];

        final result = SchemaLoader.validate(schema);

        expect(result.isValid, isFalse);
        // Should report errors for ghost1, ghost2, AND ghost3 — not stop at the first
        expect(result.errors.length, greaterThanOrEqualTo(3));
      });
    });
  });
}
