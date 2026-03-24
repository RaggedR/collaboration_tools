import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/api/models/entity.dart';

void main() {
  group('Entity.fromJson', () {
    test('deserializes a task entity', () {
      final json = {
        'id': 'abc-123',
        'type': 'task',
        'name': 'Write tests',
        'metadata': {'status': 'in_progress', 'priority': 'high'},
        'created_by': 'user-1',
        'created_at': '2026-03-20T10:00:00Z',
        'updated_at': '2026-03-20T12:00:00Z',
      };

      final entity = Entity.fromJson(json);

      expect(entity.id, equals('abc-123'));
      expect(entity.type, equals('task'));
      expect(entity.name, equals('Write tests'));
      expect(entity.metadata['status'], equals('in_progress'));
      expect(entity.metadata['priority'], equals('high'));
      expect(entity.createdBy, equals('user-1'));
      expect(entity.createdAt, isA<DateTime>());
      expect(entity.updatedAt, isA<DateTime>());
    });

    test('handles missing optional fields', () {
      final json = {
        'id': 'xyz-456',
        'type': 'document',
        'name': 'API Spec',
        'metadata': {},
        'created_at': '2026-03-20T10:00:00Z',
        'updated_at': '2026-03-20T10:00:00Z',
      };

      final entity = Entity.fromJson(json);

      expect(entity.createdBy, isNull);
      expect(entity.metadata, isEmpty);
    });

    test('handles null metadata', () {
      final json = {
        'id': 'xyz',
        'type': 'task',
        'name': 'Test',
        'metadata': null,
        'created_at': '2026-03-20T10:00:00Z',
        'updated_at': '2026-03-20T10:00:00Z',
      };

      final entity = Entity.fromJson(json);

      expect(entity.metadata, isEmpty);
    });
  });

  group('Entity.toJson', () {
    test('round-trips through fromJson/toJson', () {
      final original = {
        'id': 'abc-123',
        'type': 'sprint',
        'name': 'Sprint 1',
        'metadata': {'start_date': '2026-03-01', 'end_date': '2026-03-14'},
        'created_by': 'user-1',
        'created_at': '2026-03-20T10:00:00.000Z',
        'updated_at': '2026-03-20T12:00:00.000Z',
      };

      final entity = Entity.fromJson(original);
      final json = entity.toJson();

      expect(json['id'], equals('abc-123'));
      expect(json['type'], equals('sprint'));
      expect(json['name'], equals('Sprint 1'));
      expect(json['metadata']['start_date'], equals('2026-03-01'));
    });
  });

  group('ResolvedRelationship.fromJson', () {
    test('deserializes a forward relationship', () {
      final json = {
        'id': 'rel-1',
        'rel_type_key': 'assigned_to',
        'direction': 'forward',
        'label': 'assigned to',
        'related_entity': {
          'id': 'person-1',
          'type': 'person',
          'name': 'Robin',
        },
        'metadata': {},
      };

      final rel = ResolvedRelationship.fromJson(json);

      expect(rel.id, equals('rel-1'));
      expect(rel.relTypeKey, equals('assigned_to'));
      expect(rel.direction, equals('forward'));
      expect(rel.label, equals('assigned to'));
      expect(rel.relatedEntity.name, equals('Robin'));
      expect(rel.relatedEntity.type, equals('person'));
    });

    test('deserializes a reverse relationship', () {
      final json = {
        'id': 'rel-2',
        'rel_type_key': 'contains_task',
        'direction': 'reverse',
        'label': 'belongs to',
        'related_entity': {
          'id': 'proj-1',
          'type': 'project',
          'name': 'CMS',
        },
        'metadata': {},
      };

      final rel = ResolvedRelationship.fromJson(json);

      expect(rel.direction, equals('reverse'));
      expect(rel.label, equals('belongs to'));
    });
  });

  group('EntityWithRelationships.fromJson', () {
    test('deserializes entity with its relationships', () {
      final json = {
        'entity': {
          'id': 'task-1',
          'type': 'task',
          'name': 'Test task',
          'metadata': {'status': 'todo'},
          'created_by': 'user-1',
          'created_at': '2026-03-20T10:00:00Z',
          'updated_at': '2026-03-20T10:00:00Z',
        },
        'relationships': [
          {
            'id': 'rel-1',
            'rel_type_key': 'assigned_to',
            'direction': 'forward',
            'label': 'assigned to',
            'related_entity': {
              'id': 'person-1',
              'type': 'person',
              'name': 'Robin',
            },
            'metadata': {},
          },
        ],
      };

      final result = EntityWithRelationships.fromJson(json);

      expect(result.entity.name, equals('Test task'));
      expect(result.relationships, hasLength(1));
      expect(result.relationships.first.relatedEntity.name, equals('Robin'));
    });
  });

  group('PaginatedEntities.fromJson', () {
    test('deserializes paginated response', () {
      final json = {
        'entities': [
          {
            'id': '1',
            'type': 'task',
            'name': 'Task 1',
            'metadata': {},
            'created_at': '2026-03-20T10:00:00Z',
            'updated_at': '2026-03-20T10:00:00Z',
          },
          {
            'id': '2',
            'type': 'task',
            'name': 'Task 2',
            'metadata': {},
            'created_at': '2026-03-20T10:00:00Z',
            'updated_at': '2026-03-20T10:00:00Z',
          },
        ],
        'total': 42,
        'page': 1,
        'per_page': 50,
      };

      final result = PaginatedEntities.fromJson(json);

      expect(result.entities, hasLength(2));
      expect(result.total, equals(42));
      expect(result.page, equals(1));
      expect(result.perPage, equals(50));
    });
  });
}
