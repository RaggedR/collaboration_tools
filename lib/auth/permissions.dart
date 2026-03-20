import '../models/permission_rule.dart';

class PermissionResolver {
  final List<PermissionRule> _rules;

  PermissionResolver({required List<PermissionRule> rules}) : _rules = rules;

  /// Can this user create an entity of the given type?
  bool canCreate({required String entityType, required bool isAdmin}) {
    if (isAdmin) return true;

    // Check if this entity type is admin-only
    final isAdminOnly = _rules.any(
      (r) =>
          r.ruleType == 'admin_only_entity_type' &&
          r.entityTypeKey == entityType,
    );

    return !isAdminOnly;
  }

  /// Can this user edit this entity?
  bool canEdit({
    required String entityType,
    required bool isAdmin,
    required List<String> userRelationships,
  }) {
    if (isAdmin) return true;

    // Collect all edit-granting rel type keys
    final editGrantingRelTypes = _rules
        .where((r) => r.ruleType == 'edit_granting_rel_type')
        .map((r) => r.relTypeKey)
        .toSet();

    // Check if user has any edit-granting relationship
    return userRelationships.any(editGrantingRelTypes.contains);
  }
}
