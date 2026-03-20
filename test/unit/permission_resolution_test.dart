import 'package:test/test.dart';
import 'package:outlier/auth/permissions.dart';
import 'package:outlier/models/permission_rule.dart';

/// Tests for permission resolution behaviour.
///
/// The permission resolver takes a set of rules (from schema.config) and
/// answers questions: can this user create this entity type? Can they edit
/// this entity? The resolver must be completely generic — it reads rules,
/// not hardcoded entity type names.
void main() {
  group('Permission resolution', () {
    // Rules matching the real schema.config
    late PermissionResolver resolver;

    setUp(() {
      resolver = PermissionResolver(rules: [
        PermissionRule(
            ruleType: 'admin_only_entity_type', entityTypeKey: 'workspace'),
        PermissionRule(
            ruleType: 'admin_only_entity_type', entityTypeKey: 'person'),
        PermissionRule(
            ruleType: 'edit_granting_rel_type', relTypeKey: 'assigned_to'),
        PermissionRule(
            ruleType: 'edit_granting_rel_type', relTypeKey: 'authored'),
      ]);
    });

    // ── Entity creation ───────────────────────────────────────

    group('entity creation', () {
      test('admin can create admin-only entity types', () {
        expect(
          resolver.canCreate(entityType: 'workspace', isAdmin: true),
          isTrue,
        );
        expect(
          resolver.canCreate(entityType: 'person', isAdmin: true),
          isTrue,
        );
      });

      test('non-admin cannot create admin-only entity types', () {
        expect(
          resolver.canCreate(entityType: 'workspace', isAdmin: false),
          isFalse,
        );
        expect(
          resolver.canCreate(entityType: 'person', isAdmin: false),
          isFalse,
        );
      });

      test('non-admin can create entity types that are not admin-only', () {
        expect(
          resolver.canCreate(entityType: 'task', isAdmin: false),
          isTrue,
        );
        expect(
          resolver.canCreate(entityType: 'project', isAdmin: false),
          isTrue,
        );
        expect(
          resolver.canCreate(entityType: 'sprint', isAdmin: false),
          isTrue,
        );
        expect(
          resolver.canCreate(entityType: 'document', isAdmin: false),
          isTrue,
        );
      });

      test('admin can create all entity types', () {
        for (final type in ['workspace', 'person', 'task', 'project', 'sprint', 'document']) {
          expect(
            resolver.canCreate(entityType: type, isAdmin: true),
            isTrue,
            reason: 'admin should be able to create $type',
          );
        }
      });
    });

    // ── Entity editing ────────────────────────────────────────

    group('entity editing', () {
      test('admin can edit any entity regardless of relationships', () {
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: true,
            userRelationships: [],
          ),
          isTrue,
        );
      });

      test('user assigned to a task can edit it', () {
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: ['assigned_to'],
          ),
          isTrue,
        );
      });

      test('author of a document can edit it', () {
        expect(
          resolver.canEdit(
            entityType: 'document',
            isAdmin: false,
            userRelationships: ['authored'],
          ),
          isTrue,
        );
      });

      test('user without any edit-granting relationship cannot edit', () {
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: [],
          ),
          isFalse,
        );
      });

      test('user with unrelated relationship type cannot edit', () {
        // depends_on is not an edit-granting relationship
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: ['depends_on'],
          ),
          isFalse,
        );
      });

      test('any single matching edit-granting relationship is sufficient', () {
        // User has both assigned_to and authored — either alone should work
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: ['authored'],
          ),
          isTrue,
        );
        expect(
          resolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: ['assigned_to'],
          ),
          isTrue,
        );
      });

      test('edit-granting check is not entity-type-specific', () {
        // The assigned_to rule grants edit on ANY entity, not just tasks.
        // The resolver doesn't know (or care) that assigned_to only connects
        // tasks to people — that's a rel type constraint, not a permission
        // constraint. The permission system just checks: "does this user have
        // an edit-granting relationship to this entity?"
        expect(
          resolver.canEdit(
            entityType: 'project',
            isAdmin: false,
            userRelationships: ['assigned_to'],
          ),
          isTrue,
        );
      });
    });

    // ── No rules configured ───────────────────────────────────

    group('with no permission rules', () {
      late PermissionResolver openResolver;

      setUp(() {
        openResolver = PermissionResolver(rules: []);
      });

      test('anyone can create any entity type when no admin-only rules exist', () {
        expect(
          openResolver.canCreate(entityType: 'workspace', isAdmin: false),
          isTrue,
        );
        expect(
          openResolver.canCreate(entityType: 'task', isAdmin: false),
          isTrue,
        );
      });

      test('non-admin cannot edit when no edit-granting rules exist', () {
        // With no edit-granting rules, there's no way for a non-admin
        // to gain edit access through relationships
        expect(
          openResolver.canEdit(
            entityType: 'task',
            isAdmin: false,
            userRelationships: ['assigned_to'],
          ),
          isFalse,
        );
      });

      test('admin can always edit regardless of rules', () {
        expect(
          openResolver.canEdit(
            entityType: 'task',
            isAdmin: true,
            userRelationships: [],
          ),
          isTrue,
        );
      });
    });

    // ── Edge cases ────────────────────────────────────────────

    group('edge cases', () {
      test('handles unknown entity type gracefully (no matching rules)', () {
        // An entity type not mentioned in any rule is not admin-only
        expect(
          resolver.canCreate(entityType: 'unknown_type', isAdmin: false),
          isTrue,
        );
      });

      test('multiple admin-only rules for different types are independent', () {
        // workspace being admin-only does not affect task
        expect(
          resolver.canCreate(entityType: 'task', isAdmin: false),
          isTrue,
        );
        expect(
          resolver.canCreate(entityType: 'workspace', isAdmin: false),
          isFalse,
        );
      });
    });
  });
}
