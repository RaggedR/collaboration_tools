import 'dart:convert';
import 'dart:io';

// ── Schema Fixtures ─────────────────────────────────────────
//
// These provide valid and invalid schema.config variants for testing
// schema validation, sync, and plugin install behaviour.

/// Load the real schema.config from the project root.
Map<String, dynamic> loadSchemaConfig() {
  final file = File('schema.config');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// A minimal valid schema: one entity type, no relationships, no rules.
Map<String, dynamic> minimalValidSchema() => {
      'app': {
        'name': 'Test App',
        'description': 'A test application',
        'theme_color': '#000000',
        'logo_url': null,
      },
      'entity_types': [
        {
          'key': 'thing',
          'label': 'Thing',
          'plural': 'Things',
          'icon': 'star',
          'color': '#ff0000',
          'hidden': false,
          'metadata_schema': {
            'type': 'object',
            'properties': {
              'note': {'type': 'string'},
            },
          },
        },
      ],
      'rel_types': [],
      'permission_rules': [],
      'auto_relationships': [],
      'seed_data': {'entities': [], 'relationships': []},
    };

/// A second valid schema for testing plugin install (swap).
Map<String, dynamic> alternativeValidSchema() => {
      'app': {
        'name': 'Grant Writer',
        'description': 'Grant writing tool',
        'theme_color': '#059669',
        'logo_url': null,
      },
      'entity_types': [
        {
          'key': 'grant',
          'label': 'Grant',
          'plural': 'Grants',
          'icon': 'description',
          'color': '#059669',
          'hidden': false,
          'metadata_schema': {
            'type': 'object',
            'properties': {
              'status': {
                'type': 'string',
                'enum': ['draft', 'submitted', 'awarded', 'rejected'],
              },
              'amount': {'type': 'number'},
            },
          },
        },
        {
          'key': 'funder',
          'label': 'Funder',
          'plural': 'Funders',
          'icon': 'account_balance',
          'color': '#7c3aed',
          'hidden': false,
          'metadata_schema': {
            'type': 'object',
            'properties': {
              'website': {'type': 'string', 'format': 'uri'},
            },
          },
        },
      ],
      'rel_types': [
        {
          'key': 'funded_by',
          'forward_label': 'funded by',
          'reverse_label': 'funds',
          'source_types': ['grant'],
          'target_types': ['funder'],
          'symmetric': false,
        },
      ],
      'permission_rules': [],
      'auto_relationships': [],
      'seed_data': {'entities': [], 'relationships': []},
    };

// ── Invalid Schema Variants ─────────────────────────────────

Map<String, dynamic> schemaMissingApp() {
  final schema = minimalValidSchema();
  schema.remove('app');
  return schema;
}

Map<String, dynamic> schemaMissingEntityTypes() {
  final schema = minimalValidSchema();
  schema.remove('entity_types');
  return schema;
}

Map<String, dynamic> schemaDuplicateEntityKeys() {
  final schema = minimalValidSchema();
  schema['entity_types'] = [
    ...(schema['entity_types'] as List),
    {
      'key': 'thing', // duplicate
      'label': 'Another Thing',
      'plural': 'Other Things',
      'icon': 'circle',
      'color': '#00ff00',
      'hidden': false,
    },
  ];
  return schema;
}

Map<String, dynamic> schemaEntityTypeMissingKey() {
  final schema = minimalValidSchema();
  schema['entity_types'] = [
    {
      // 'key' is missing
      'label': 'Orphan',
      'plural': 'Orphans',
      'icon': 'star',
      'color': '#ff0000',
      'hidden': false,
    },
  ];
  return schema;
}

Map<String, dynamic> schemaRelTypeInvalidSourceType() {
  final schema = minimalValidSchema();
  schema['rel_types'] = [
    {
      'key': 'broken_rel',
      'forward_label': 'links to',
      'reverse_label': 'linked from',
      'source_types': ['nonexistent_type'],
      'target_types': ['thing'],
      'symmetric': false,
    },
  ];
  return schema;
}

Map<String, dynamic> schemaRelTypeInvalidTargetType() {
  final schema = minimalValidSchema();
  schema['rel_types'] = [
    {
      'key': 'broken_rel',
      'forward_label': 'points to',
      'reverse_label': 'pointed from',
      'source_types': ['thing'],
      'target_types': ['ghost'],
      'symmetric': false,
    },
  ];
  return schema;
}

Map<String, dynamic> schemaDuplicateRelKeys() {
  final schema = minimalValidSchema();
  schema['rel_types'] = [
    {
      'key': 'dup',
      'forward_label': 'a',
      'reverse_label': 'b',
      'source_types': ['thing'],
      'target_types': ['thing'],
      'symmetric': false,
    },
    {
      'key': 'dup',
      'forward_label': 'c',
      'reverse_label': 'd',
      'source_types': ['thing'],
      'target_types': ['thing'],
      'symmetric': false,
    },
  ];
  return schema;
}

Map<String, dynamic> schemaPermissionInvalidEntityType() {
  final schema = minimalValidSchema();
  schema['permission_rules'] = [
    {'rule_type': 'admin_only_entity_type', 'entity_type_key': 'ghost'},
  ];
  return schema;
}

Map<String, dynamic> schemaPermissionInvalidRelType() {
  final schema = minimalValidSchema();
  schema['permission_rules'] = [
    {'rule_type': 'edit_granting_rel_type', 'rel_type_key': 'phantom'},
  ];
  return schema;
}

Map<String, dynamic> schemaAutoRelInvalidRelType() {
  final schema = minimalValidSchema();
  schema['auto_relationships'] = [
    {
      'trigger': 'create',
      'entity_type': 'thing',
      'rel_type_key': 'nonexistent_rel',
      'target': 'current_user',
    },
  ];
  return schema;
}

Map<String, dynamic> schemaAutoRelInvalidEntityType() {
  final schema = minimalValidSchema();
  schema['auto_relationships'] = [
    {
      'trigger': 'create',
      'entity_type': 'nonexistent',
      'rel_type_key': 'some_rel',
      'target': 'current_user',
    },
  ];
  return schema;
}

// ── Test User Credentials ───────────────────────────────────

const adminEmail = 'admin@test.com';
const adminPassword = 'admin-test-password';
const adminName = 'Test Admin';

const userEmail = 'user@test.com';
const userPassword = 'user-test-password';
const userName = 'Test User';

const testDatabaseUrl = 'postgresql://outlier:outlier@localhost:5433/outlier_test';
