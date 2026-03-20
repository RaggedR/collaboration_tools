import 'package:postgres/postgres.dart';

import 'database.dart';
import '../models/entity_type.dart';
import '../models/rel_type.dart';
import '../models/permission_rule.dart';

class SchemaQueries {
  final Database db;

  SchemaQueries({required this.db});

  Future<List<EntityType>> listEntityTypes() async {
    final result = await db.query(
      'SELECT * FROM entity_types ORDER BY sort_order, key',
    );
    return result.map(_rowToEntityType).toList();
  }

  Future<EntityType> getEntityType(String key) async {
    final result = await db.query(
      Sql.named('SELECT * FROM entity_types WHERE key = @key'),
      parameters: {'key': key},
    );
    if (result.isEmpty) throw StateError('Entity type not found: $key');
    return _rowToEntityType(result.first);
  }

  Future<List<RelType>> listRelTypes() async {
    final result = await db.query('SELECT * FROM rel_types ORDER BY key');
    return result.map(_rowToRelType).toList();
  }

  Future<RelType> getRelType(String key) async {
    final result = await db.query(
      Sql.named('SELECT * FROM rel_types WHERE key = @key'),
      parameters: {'key': key},
    );
    if (result.isEmpty) throw StateError('Rel type not found: $key');
    return _rowToRelType(result.first);
  }

  Future<List<PermissionRule>> listPermissionRules() async {
    final result = await db.query('SELECT * FROM permission_rules');
    return result.map(_rowToPermissionRule).toList();
  }

  EntityType _rowToEntityType(dynamic row) {
    final m = (row as ResultRow).toColumnMap();
    return EntityType(
      key: m['key'] as String,
      label: m['label'] as String,
      plural: m['plural'] as String,
      icon: m['icon'] as String?,
      color: (m['color'] as String?) ?? '#6b7280',
      hidden: (m['hidden'] as bool?) ?? false,
      metadataSchema: m['metadata_schema'] as Map<String, dynamic>?,
      sortOrder: (m['sort_order'] as int?) ?? 0,
    );
  }

  RelType _rowToRelType(dynamic row) {
    final m = (row as ResultRow).toColumnMap();
    return RelType(
      key: m['key'] as String,
      forwardLabel: m['forward_label'] as String,
      reverseLabel: m['reverse_label'] as String,
      sourceTypes: (m['source_types'] as List).cast<String>(),
      targetTypes: (m['target_types'] as List).cast<String>(),
      symmetric: (m['symmetric'] as bool?) ?? false,
      metadataSchema: m['metadata_schema'] as Map<String, dynamic>?,
    );
  }

  PermissionRule _rowToPermissionRule(dynamic row) {
    final m = (row as ResultRow).toColumnMap();
    return PermissionRule(
      ruleType: m['rule_type'] as String,
      entityTypeKey: m['entity_type_key'] as String?,
      relTypeKey: m['rel_type_key'] as String?,
    );
  }
}
