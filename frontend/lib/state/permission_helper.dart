import '../api/models/schema.dart';
import '../api/models/entity.dart';

/// Frontend permission helper — determines what UI elements to show.
///
/// This never enforces permissions (the backend does that). It only
/// controls whether buttons, forms, and drag-and-drop are visible.
class PermissionHelper {
  final List<PermissionRule> permissionRules;
  final bool isAdmin;
  final String? personEntityId;

  PermissionHelper({
    required this.permissionRules,
    required this.isAdmin,
    this.personEntityId,
  });

  /// Can this user create entities of the given type?
  bool canCreate(String entityType) {
    if (isAdmin) return true;
    return !permissionRules.any(
      (r) =>
          r.ruleType == 'admin_only_entity_type' &&
          r.entityTypeKey == entityType,
    );
  }

  /// Can this user edit this entity, given its relationships?
  bool canEdit(Entity entity, List<ResolvedRelationship> relationships) {
    if (isAdmin) return true;

    // Collect edit-granting rel type keys
    final editGrantingRelTypes = permissionRules
        .where((r) => r.ruleType == 'edit_granting_rel_type')
        .map((r) => r.relTypeKey)
        .whereType<String>()
        .toSet();

    // Check if the current user's person entity has an edit-granting rel
    if (personEntityId != null) {
      for (final rel in relationships) {
        if (editGrantingRelTypes.contains(rel.relTypeKey) &&
            rel.relatedEntity.id == personEntityId) {
          return true;
        }
      }
    }

    return false;
  }

  /// Can this user edit content on this person's page?
  bool canEditPage(String pagePersonId) {
    if (isAdmin) return true;
    return personEntityId == pagePersonId;
  }
}
