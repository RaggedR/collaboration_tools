import 'package:test/test.dart';
import 'package:outlier/config/metadata_validator.dart';

/// Tests for metadata validation against JSON Schema.
///
/// Each entity type in schema.config can define a metadata_schema. When
/// creating or updating an entity, metadata must conform to this schema.
/// These tests verify the validation behaviour for each JSON Schema
/// feature used in the real schema.config.
void main() {
  // Task metadata schema — the most complex one in schema.config
  final taskSchema = {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['backlog', 'todo', 'in_progress', 'review', 'done', 'archived'],
      },
      'priority': {
        'type': 'string',
        'enum': ['low', 'medium', 'high', 'urgent'],
      },
      'deadline': {'type': 'string', 'format': 'date'},
      'estimate': {'type': 'number'},
      'labels': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  // Sprint metadata schema — has required fields
  final sprintSchema = {
    'type': 'object',
    'properties': {
      'start_date': {'type': 'string', 'format': 'date'},
      'end_date': {'type': 'string', 'format': 'date'},
      'goal': {'type': 'string'},
    },
    'required': ['start_date', 'end_date'],
  };

  // Project metadata schema
  final projectSchema = {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['active', 'paused', 'completed', 'archived'],
      },
      'deadline': {'type': 'string', 'format': 'date'},
      'description': {'type': 'string'},
    },
  };

  group('Metadata validation', () {
    // ── Valid metadata ──────────────────────────────────────

    group('accepts valid metadata', () {
      test('accepts metadata with all fields matching schema', () {
        final result = MetadataValidator.validate(taskSchema, {
          'status': 'in_progress',
          'priority': 'high',
          'deadline': '2026-04-01',
          'estimate': 3,
          'labels': ['frontend', 'urgent'],
        });

        expect(result.isValid, isTrue);
      });

      test('accepts metadata with only some optional fields', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'status': 'backlog'},
        );

        expect(result.isValid, isTrue);
      });

      test('accepts empty metadata when no fields are required', () {
        final result = MetadataValidator.validate(taskSchema, {});

        expect(result.isValid, isTrue);
      });

      test('accepts null metadata_schema (no validation applied)', () {
        final result =
            MetadataValidator.validate(null, {'anything': 'goes', 'x': 42});

        expect(result.isValid, isTrue);
      });

      test('accepts each valid project status', () {
        for (final status in ['active', 'paused', 'completed', 'archived']) {
          final result = MetadataValidator.validate(
            projectSchema,
            {'status': status},
          );
          expect(result.isValid, isTrue, reason: 'status "$status" should be valid');
        }
      });
    });

    // ── Enum validation ─────────────────────────────────────

    group('rejects invalid enum values', () {
      test('rejects task status not in enum', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'status': 'cancelled'},
        );

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('status')));
      });

      test('rejects priority not in enum', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'priority': 'critical'},
        );

        expect(result.isValid, isFalse);
      });

      test('rejects project status not in enum', () {
        final result = MetadataValidator.validate(
          projectSchema,
          {'status': 'deleted'},
        );

        expect(result.isValid, isFalse);
      });
    });

    // ── Type checking ───────────────────────────────────────

    group('rejects wrong types', () {
      test('rejects non-number for number field', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'estimate': 'three'},
        );

        expect(result.isValid, isFalse);
      });

      test('rejects non-string for string field', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'status': 42},
        );

        expect(result.isValid, isFalse);
      });

      test('rejects non-array for array field', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'labels': 'not-an-array'},
        );

        expect(result.isValid, isFalse);
      });

      test('rejects non-string items in string array', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'labels': [1, 2, 3]},
        );

        expect(result.isValid, isFalse);
      });
    });

    // ── Required fields ─────────────────────────────────────

    group('enforces required fields', () {
      test('rejects missing required fields', () {
        // Sprint requires start_date and end_date
        final result = MetadataValidator.validate(
          sprintSchema,
          {'goal': 'Ship v1'},
        );

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('start_date')));
      });

      test('rejects when only some required fields are present', () {
        final result = MetadataValidator.validate(
          sprintSchema,
          {'start_date': '2026-03-20'},
        );

        expect(result.isValid, isFalse);
        expect(result.errors, anyElement(contains('end_date')));
      });

      test('accepts when all required fields are present', () {
        final result = MetadataValidator.validate(
          sprintSchema,
          {'start_date': '2026-03-20', 'end_date': '2026-04-03'},
        );

        expect(result.isValid, isTrue);
      });

      test('accepts required fields plus optional fields', () {
        final result = MetadataValidator.validate(
          sprintSchema,
          {
            'start_date': '2026-03-20',
            'end_date': '2026-04-03',
            'goal': 'Ship v1',
          },
        );

        expect(result.isValid, isTrue);
      });
    });

    // ── Date format ─────────────────────────────────────────

    group('validates date format', () {
      test('accepts valid ISO date (YYYY-MM-DD)', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'deadline': '2026-04-01'},
        );

        expect(result.isValid, isTrue);
      });

      test('rejects human-readable date strings', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'deadline': 'next Tuesday'},
        );

        expect(result.isValid, isFalse);
      });

      test('rejects ISO datetime (only date is expected)', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'deadline': '2026-04-01T10:00:00Z'},
        );

        // Date format should be YYYY-MM-DD, not full datetime
        expect(result.isValid, isFalse);
      });
    });

    // ── Number validation ───────────────────────────────────

    group('validates number fields', () {
      test('accepts integer for number field', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'estimate': 5},
        );

        expect(result.isValid, isTrue);
      });

      test('accepts decimal for number field', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'estimate': 2.5},
        );

        expect(result.isValid, isTrue);
      });

      test('accepts zero', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'estimate': 0},
        );

        expect(result.isValid, isTrue);
      });
    });

    // ── Array validation ────────────────────────────────────

    group('validates array fields', () {
      test('accepts empty array', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'labels': []},
        );

        expect(result.isValid, isTrue);
      });

      test('accepts array of valid strings', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'labels': ['bug', 'frontend', 'P0']},
        );

        expect(result.isValid, isTrue);
      });

      test('rejects mixed-type array when items must be strings', () {
        final result = MetadataValidator.validate(
          taskSchema,
          {'labels': ['valid', 42, true]},
        );

        expect(result.isValid, isFalse);
      });
    });
  });
}
