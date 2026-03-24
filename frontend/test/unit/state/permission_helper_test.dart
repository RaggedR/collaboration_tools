import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/state/permission_helper.dart';
import 'package:collaboration_tools/api/models/schema.dart';
import 'package:collaboration_tools/api/models/entity.dart';

void main() {
  // Mirror of the real schema.config permission rules
  final rules = [
    PermissionRule(
        ruleType: 'admin_only_entity_type', entityTypeKey: 'workspace'),
    PermissionRule(
        ruleType: 'admin_only_entity_type', entityTypeKey: 'person'),
    PermissionRule(
        ruleType: 'edit_granting_rel_type', relTypeKey: 'assigned_to'),
    PermissionRule(
        ruleType: 'edit_granting_rel_type', relTypeKey: 'authored'),
  ];

  group('canCreate', () {
    test('admin can create any entity type', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: true,
        personEntityId: 'person-1',
      );

      expect(helper.canCreate('workspace'), isTrue);
      expect(helper.canCreate('person'), isTrue);
      expect(helper.canCreate('task'), isTrue);
      expect(helper.canCreate('project'), isTrue);
    });

    test('non-admin cannot create admin-only types', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      expect(helper.canCreate('workspace'), isFalse);
      expect(helper.canCreate('person'), isFalse);
    });

    test('non-admin can create non-admin types', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      expect(helper.canCreate('task'), isTrue);
      expect(helper.canCreate('project'), isTrue);
      expect(helper.canCreate('sprint'), isTrue);
      expect(helper.canCreate('document'), isTrue);
    });
  });

  group('canEdit', () {
    final taskEntity = Entity(
      id: 'task-1',
      type: 'task',
      name: 'Test task',
      metadata: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('admin can edit any entity', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: true,
        personEntityId: 'person-1',
      );

      expect(helper.canEdit(taskEntity, []), isTrue);
    });

    test('user can edit entity if they have an edit-granting relationship', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      final rels = [
        ResolvedRelationship(
          id: 'rel-1',
          relTypeKey: 'assigned_to',
          direction: 'forward',
          label: 'assigned to',
          relatedEntity: RelatedEntity(
            id: 'person-1', // matches current user
            type: 'person',
            name: 'Robin',
          ),
          metadata: {},
        ),
      ];

      expect(helper.canEdit(taskEntity, rels), isTrue);
    });

    test('user cannot edit entity without edit-granting relationship', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      final rels = [
        ResolvedRelationship(
          id: 'rel-1',
          relTypeKey: 'assigned_to',
          direction: 'forward',
          label: 'assigned to',
          relatedEntity: RelatedEntity(
            id: 'person-2', // different person
            type: 'person',
            name: 'Sarah',
          ),
          metadata: {},
        ),
      ];

      expect(helper.canEdit(taskEntity, rels), isFalse);
    });

    test('user cannot edit entity with non-edit-granting relationship', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      final rels = [
        ResolvedRelationship(
          id: 'rel-1',
          relTypeKey: 'in_sprint', // not edit-granting
          direction: 'forward',
          label: 'scheduled in',
          relatedEntity: RelatedEntity(
            id: 'person-1',
            type: 'person',
            name: 'Robin',
          ),
          metadata: {},
        ),
      ];

      expect(helper.canEdit(taskEntity, rels), isFalse);
    });

    test('authored relationship grants edit on documents', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      final docEntity = Entity(
        id: 'doc-1',
        type: 'document',
        name: 'API Spec',
        metadata: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final rels = [
        ResolvedRelationship(
          id: 'rel-1',
          relTypeKey: 'authored',
          direction: 'reverse', // document's perspective: authored by person
          label: 'authored by',
          relatedEntity: RelatedEntity(
            id: 'person-1',
            type: 'person',
            name: 'Robin',
          ),
          metadata: {},
        ),
      ];

      expect(helper.canEdit(docEntity, rels), isTrue);
    });
  });

  group('canEditPage', () {
    test('admin can edit any page', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: true,
        personEntityId: 'person-1',
      );

      expect(helper.canEditPage('person-1'), isTrue);
      expect(helper.canEditPage('person-2'), isTrue);
      expect(helper.canEditPage('person-999'), isTrue);
    });

    test('user can edit own page', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      expect(helper.canEditPage('person-1'), isTrue);
    });

    test('user cannot edit others page', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: 'person-1',
      );

      expect(helper.canEditPage('person-2'), isFalse);
    });

    test('user with null personEntityId cannot edit any page', () {
      final helper = PermissionHelper(
        permissionRules: rules,
        isAdmin: false,
        personEntityId: null,
      );

      expect(helper.canEditPage('person-1'), isFalse);
    });
  });
}
