import '../models/entity_type.dart';
import '../models/rel_type.dart';
import '../models/permission_rule.dart';

class SchemaCache {
  final _entityTypes = <String, EntityType>{};
  final _relTypes = <String, RelType>{};
  final _permissionRules = <PermissionRule>[];
  Map<String, dynamic> _appConfig = {};
  List<Map<String, dynamic>> _autoRelationships = [];

  /// Populates the cache from a parsed schema.config.
  void refresh(Map<String, dynamic> config) {
    _entityTypes.clear();
    _relTypes.clear();
    _permissionRules.clear();

    _appConfig =
        (config['app'] as Map<String, dynamic>?) ?? {};

    final entityTypes = config['entity_types'] as List? ?? [];
    for (final et in entityTypes) {
      final entityType = EntityType.fromJson(et as Map<String, dynamic>);
      _entityTypes[entityType.key] = entityType;
    }

    final relTypes = config['rel_types'] as List? ?? [];
    for (final rt in relTypes) {
      final relType = RelType.fromJson(rt as Map<String, dynamic>);
      _relTypes[relType.key] = relType;
    }

    final rules = config['permission_rules'] as List? ?? [];
    for (final r in rules) {
      _permissionRules.add(PermissionRule.fromJson(r as Map<String, dynamic>));
    }

    _autoRelationships = (config['auto_relationships'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
  }

  // Lookups

  EntityType? getEntityType(String key) => _entityTypes[key];
  RelType? getRelType(String key) => _relTypes[key];

  bool hasEntityType(String key) => _entityTypes.containsKey(key);
  bool hasRelType(String key) => _relTypes.containsKey(key);

  List<EntityType> get entityTypes => _entityTypes.values.toList();
  List<RelType> get relTypes => _relTypes.values.toList();
  List<PermissionRule> get permissionRules =>
      List.unmodifiable(_permissionRules);
  Map<String, dynamic> get appConfig => _appConfig;
  List<Map<String, dynamic>> get autoRelationships => _autoRelationships;
}
