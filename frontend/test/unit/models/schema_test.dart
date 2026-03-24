import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/api/models/schema.dart';

void main() {
  group('Schema.fromJson', () {
    test('deserializes full schema response', () {
      final json = {
        'app': {
          'name': 'Collaboration Tools',
          'description': 'Collaboration tools with kanban and knowledge graph',
          'theme_color': '#2563eb',
          'logo_url': null,
        },
        'entity_types': [
          {
            'key': 'task',
            'label': 'Task',
            'plural': 'Tasks',
            'icon': 'check_circle',
            'color': '#10b981',
            'hidden': false,
            'metadata_schema': {
              'type': 'object',
              'properties': {
                'status': {
                  'type': 'string',
                  'enum': [
                    'backlog',
                    'todo',
                    'in_progress',
                    'review',
                    'done',
                    'archived'
                  ],
                },
              },
            },
          },
        ],
        'rel_types': [
          {
            'key': 'assigned_to',
            'forward_label': 'assigned to',
            'reverse_label': 'responsible for',
            'source_types': ['task'],
            'target_types': ['person'],
            'symmetric': false,
          },
        ],
        'permission_rules': [
          {
            'rule_type': 'admin_only_entity_type',
            'entity_type_key': 'workspace',
          },
          {
            'rule_type': 'edit_granting_rel_type',
            'rel_type_key': 'assigned_to',
          },
        ],
      };

      final schema = Schema.fromJson(json);

      expect(schema.app.name, equals('Collaboration Tools'));
      expect(schema.app.themeColor, equals('#2563eb'));
      expect(schema.entityTypes, hasLength(1));
      expect(schema.entityTypes.first.key, equals('task'));
      expect(schema.relTypes, hasLength(1));
      expect(schema.relTypes.first.forwardLabel, equals('assigned to'));
      expect(schema.permissionRules, hasLength(2));
    });
  });

  group('EntityType.fromJson', () {
    test('deserializes entity type with metadata schema', () {
      final json = {
        'key': 'sprint',
        'label': 'Sprint',
        'plural': 'Sprints',
        'icon': 'timer',
        'color': '#8b5cf6',
        'hidden': false,
        'metadata_schema': {
          'type': 'object',
          'properties': {
            'start_date': {'type': 'string', 'format': 'date'},
            'end_date': {'type': 'string', 'format': 'date'},
            'goal': {'type': 'string'},
          },
          'required': ['start_date', 'end_date'],
        },
      };

      final et = EntityType.fromJson(json);

      expect(et.key, equals('sprint'));
      expect(et.label, equals('Sprint'));
      expect(et.color, equals('#8b5cf6'));
      expect(et.metadataSchema['required'], contains('start_date'));
    });
  });

  group('RelType.fromJson', () {
    test('deserializes symmetric relationship type', () {
      final json = {
        'key': 'collaborates',
        'forward_label': 'works with',
        'reverse_label': 'works with',
        'source_types': ['person'],
        'target_types': ['person'],
        'symmetric': true,
      };

      final rt = RelType.fromJson(json);

      expect(rt.key, equals('collaborates'));
      expect(rt.symmetric, isTrue);
      expect(rt.sourceTypes, equals(['person']));
      expect(rt.targetTypes, equals(['person']));
    });

    test('deserializes asymmetric relationship type', () {
      final json = {
        'key': 'assigned_to',
        'forward_label': 'assigned to',
        'reverse_label': 'responsible for',
        'source_types': ['task'],
        'target_types': ['person'],
        'symmetric': false,
      };

      final rt = RelType.fromJson(json);

      expect(rt.forwardLabel, equals('assigned to'));
      expect(rt.reverseLabel, equals('responsible for'));
      expect(rt.symmetric, isFalse);
    });
  });

  group('PermissionRule.fromJson', () {
    test('deserializes admin_only_entity_type rule', () {
      final json = {
        'rule_type': 'admin_only_entity_type',
        'entity_type_key': 'workspace',
      };

      final rule = PermissionRule.fromJson(json);

      expect(rule.ruleType, equals('admin_only_entity_type'));
      expect(rule.entityTypeKey, equals('workspace'));
      expect(rule.relTypeKey, isNull);
    });

    test('deserializes edit_granting_rel_type rule', () {
      final json = {
        'rule_type': 'edit_granting_rel_type',
        'rel_type_key': 'assigned_to',
      };

      final rule = PermissionRule.fromJson(json);

      expect(rule.ruleType, equals('edit_granting_rel_type'));
      expect(rule.relTypeKey, equals('assigned_to'));
      expect(rule.entityTypeKey, isNull);
    });
  });
}
