import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../db/database.dart';
import 'validation_result.dart';

export 'validation_result.dart';

class SchemaLoader {
  /// Validates a parsed schema.config against structural rules.
  /// Collects all errors — does not stop at the first.
  static ValidationResult validate(Map<String, dynamic> config) {
    final errors = <String>[];
    final entityTypeKeys = <String>{};
    final relTypeKeys = <String>{};

    // Required top-level sections
    if (!config.containsKey('app')) {
      errors.add("Missing required section: 'app'");
    }
    if (!config.containsKey('entity_types')) {
      errors.add("Missing required section: 'entity_types'");
    }

    // Validate entity types
    final entityTypes = config['entity_types'];
    if (entityTypes is List) {
      for (final et in entityTypes) {
        if (et is! Map<String, dynamic>) continue;
        if (!et.containsKey('key')) {
          errors.add("Entity type missing required field: 'key'");
          continue;
        }
        final key = et['key'] as String;
        if (!entityTypeKeys.add(key)) {
          errors.add("duplicate entity type key: '$key'");
        }

        // Validate ui_schema field references against metadata_schema
        final uiSchema = et['ui_schema'] as Map<String, dynamic>?;
        final metaSchema = et['metadata_schema'] as Map<String, dynamic>?;
        if (uiSchema != null && metaSchema != null) {
          final metaProps =
              (metaSchema['properties'] as Map?)?.keys.toSet() ?? <String>{};
          _validateUiSchemaRefs(errors, key, uiSchema, metaProps);
        }
      }
    }

    // Validate relationship types
    final relTypes = config['rel_types'];
    if (relTypes is List) {
      for (final rt in relTypes) {
        if (rt is! Map<String, dynamic>) continue;
        final key = rt['key'] as String?;
        if (key != null && !relTypeKeys.add(key)) {
          errors.add("Duplicate relationship type key: '$key'");
        }

        final sourceTypes = rt['source_types'];
        if (sourceTypes is List) {
          for (final st in sourceTypes) {
            if (!entityTypeKeys.contains(st)) {
              errors.add(
                  "Relationship type '${key ?? '?'}' references unknown source type: '$st'");
            }
          }
        }

        final targetTypes = rt['target_types'];
        if (targetTypes is List) {
          for (final tt in targetTypes) {
            if (!entityTypeKeys.contains(tt)) {
              errors.add(
                  "Relationship type '${key ?? '?'}' references unknown target type: '$tt'");
            }
          }
        }
      }
    }

    // Validate permission rules
    final rules = config['permission_rules'];
    if (rules is List) {
      for (final rule in rules) {
        if (rule is! Map<String, dynamic>) continue;
        final ruleType = rule['rule_type'] as String?;

        if (ruleType == 'admin_only_entity_type') {
          final etk = rule['entity_type_key'] as String?;
          if (etk != null && !entityTypeKeys.contains(etk)) {
            errors.add(
                "Permission rule references unknown entity type: '$etk'");
          }
        } else if (ruleType == 'edit_granting_rel_type' ||
            ruleType == 'requires_approval_rel_type' ||
            ruleType == 'admin_only_rel_type') {
          final rtk = rule['rel_type_key'] as String?;
          if (rtk != null && !relTypeKeys.contains(rtk)) {
            errors.add(
                "Permission rule references unknown rel type: '$rtk'");
          }
        }
      }
    }

    // Validate auto-relationships
    final autoRels = config['auto_relationships'];
    if (autoRels is List) {
      for (final ar in autoRels) {
        if (ar is! Map<String, dynamic>) continue;
        final entityType = ar['entity_type'] as String?;
        if (entityType != null && !entityTypeKeys.contains(entityType)) {
          errors.add(
              "Auto-relationship references unknown entity type: '$entityType'");
        }
        final relTypeKey = ar['rel_type_key'] as String?;
        if (relTypeKey != null && !relTypeKeys.contains(relTypeKey)) {
          errors.add(
              "Auto-relationship references unknown rel type: '$relTypeKey'");
        }
      }
    }

    return ValidationResult(errors);
  }

  /// Checks that ui_schema field references (ui:order, card.fields,
  /// detail.sections[].fields, filters) all point to real metadata properties.
  static void _validateUiSchemaRefs(
    List<String> errors,
    String entityKey,
    Map<String, dynamic> uiSchema,
    Set<dynamic> metaProps,
  ) {
    void checkField(String context, String field) {
      // Skip relationship refs like "@project.name"
      if (field.startsWith('@')) return;
      if (!metaProps.contains(field)) {
        errors.add(
            "ui_schema for '$entityKey' $context references unknown field: '$field'");
      }
    }

    // ui:order
    final order = uiSchema['ui:order'] as List?;
    if (order != null) {
      for (final f in order) {
        checkField('ui:order', f as String);
      }
    }

    // card.fields
    final card = uiSchema['card'] as Map<String, dynamic>?;
    if (card != null) {
      final cardFields = card['fields'] as List?;
      if (cardFields != null) {
        for (final f in cardFields) {
          checkField('card.fields', f as String);
        }
      }
    }

    // detail.sections[].fields
    final detail = uiSchema['detail'] as Map<String, dynamic>?;
    if (detail != null) {
      final sections = detail['sections'] as List?;
      if (sections != null) {
        for (final section in sections) {
          final s = section as Map<String, dynamic>;
          final fields = s['fields'] as List?;
          if (fields != null) {
            for (final f in fields) {
              checkField('detail.sections', f as String);
            }
          }
        }
      }
    }

    // filters
    final filters = uiSchema['filters'] as List?;
    if (filters != null) {
      for (final f in filters) {
        checkField('filters', f as String);
      }
    }

    // properties — check that ui_schema.properties keys match metadata_schema
    final uiProps = uiSchema['properties'] as Map<String, dynamic>?;
    if (uiProps != null) {
      for (final key in uiProps.keys) {
        checkField('properties', key);
      }
    }
  }

  /// Syncs a validated config into the database.
  /// Runs in a single transaction: upserts entity_types, upserts rel_types,
  /// replaces permission_rules.
  /// Throws on invalid config (database is not partially updated).
  static Future<void> syncToDatabase(
    Map<String, dynamic> config,
    Database db,
  ) async {
    final result = validate(config);
    if (!result.isValid) {
      throw StateError('Invalid config: ${result.errors.join(', ')}');
    }

    await db.runTx((tx) async {
      // Delete permission_rules first (FK to rel_types and entity_types)
      await tx.execute('DELETE FROM permission_rules');

      // Upsert entity types
      final entityTypes = config['entity_types'] as List? ?? [];
      for (final et in entityTypes) {
        final m = et as Map<String, dynamic>;
        await tx.execute(
          Sql.named('''
            INSERT INTO entity_types (key, label, plural, icon, color, hidden, metadata_schema, ui_schema, sort_order)
            VALUES (@key, @label, @plural, @icon, @color, @hidden, @metadataSchema, @uiSchema, @sortOrder)
            ON CONFLICT (key) DO UPDATE SET
              label = @label,
              plural = @plural,
              icon = @icon,
              color = @color,
              hidden = @hidden,
              metadata_schema = @metadataSchema,
              ui_schema = @uiSchema,
              sort_order = @sortOrder
          '''),
          parameters: {
            'key': m['key'],
            'label': m['label'],
            'plural': m['plural'],
            'icon': m['icon'],
            'color': m['color'] ?? '#6b7280',
            'hidden': m['hidden'] ?? false,
            'metadataSchema': m['metadata_schema'] != null
                ? jsonEncode(m['metadata_schema'])
                : null,
            'uiSchema': m['ui_schema'] != null
                ? jsonEncode(m['ui_schema'])
                : null,
            'sortOrder': m['sort_order'] ?? 0,
          },
        );
      }

      // Upsert rel types
      final relTypes = config['rel_types'] as List? ?? [];
      for (final rt in relTypes) {
        final m = rt as Map<String, dynamic>;
        await tx.execute(
          Sql.named('''
            INSERT INTO rel_types (key, forward_label, reverse_label, source_types, target_types, "symmetric", metadata_schema)
            VALUES (@key, @forwardLabel, @reverseLabel, @sourceTypes, @targetTypes, @symmetric, @metadataSchema)
            ON CONFLICT (key) DO UPDATE SET
              forward_label = @forwardLabel,
              reverse_label = @reverseLabel,
              source_types = @sourceTypes,
              target_types = @targetTypes,
              "symmetric" = @symmetric,
              metadata_schema = @metadataSchema
          '''),
          parameters: {
            'key': m['key'],
            'forwardLabel': m['forward_label'],
            'reverseLabel': m['reverse_label'],
            'sourceTypes': (m['source_types'] as List).cast<String>(),
            'targetTypes': (m['target_types'] as List).cast<String>(),
            'symmetric': m['symmetric'] ?? false,
            'metadataSchema': m['metadata_schema'] != null
                ? jsonEncode(m['metadata_schema'])
                : null,
          },
        );
      }

      // Insert permission rules (already deleted above)
      final rules = config['permission_rules'] as List? ?? [];
      for (final rule in rules) {
        final m = rule as Map<String, dynamic>;
        await tx.execute(
          Sql.named('''
            INSERT INTO permission_rules (rule_type, entity_type_key, rel_type_key)
            VALUES (@ruleType, @entityTypeKey, @relTypeKey)
          '''),
          parameters: {
            'ruleType': m['rule_type'],
            'entityTypeKey': m['entity_type_key'],
            'relTypeKey': m['rel_type_key'],
          },
        );
      }
    });
  }
}
