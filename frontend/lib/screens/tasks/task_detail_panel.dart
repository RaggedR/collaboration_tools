import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/entity_detail_state.dart';
import '../../state/providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/shared/error_snackbar.dart';
import '../../widgets/shared/metadata_form.dart';
import '../../widgets/shared/priority_badge.dart';
import '../../widgets/shared/relationship_list.dart';
import '../../widgets/shared/status_badge.dart';
import '../../api/api_client.dart';
import '../../api/models/schema.dart';

/// Detail panel for a single task — metadata, relationships, edit/delete.
class TaskDetailPanel extends ConsumerWidget {
  final String taskId;
  final VoidCallback? onClose;
  final VoidCallback? onDeleted;

  const TaskDetailPanel({
    super.key,
    required this.taskId,
    this.onClose,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(entityDetailProvider(taskId));
    final permissions = ref.watch(permissionProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entityWithRels) {
          final entity = entityWithRels.entity;
          final rels = entityWithRels.relationships;
          final canEdit = permissions?.canEdit(entity, rels) ?? false;
          final status = entity.metadata['status'] as String?;
          final priority = entity.metadata['priority'] as String?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entity.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Status + Priority badges
              Wrap(
                spacing: 8,
                children: [
                  if (status != null) StatusBadge(status: status),
                  if (priority != null) PriorityBadge(priority: priority),
                ],
              ),
              const SizedBox(height: 16),

              // Relationships
              RelationshipList(
                relationships: rels,
                readOnly: !canEdit,
              ),

              // Edit / Delete actions
              if (canEdit) ...[
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      onPressed: () => _showEditDialog(context, ref, entity),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.delete, size: 18,
                          color: Theme.of(context).colorScheme.error),
                      label: Text('Delete',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      onPressed: () => _delete(context, ref),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, entity) async {
    final schemaAsync = ref.read(schemaProvider);
    final taskType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'task', orElse: () => null);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: SizedBox(
          width: 400,
          child: MetadataForm(
            metadataSchema: taskType?.metadataSchema ?? {},
            initialName: entity.name,
            initialValues: Map<String, dynamic>.from(entity.metadata),
            onSubmit: (name, metadata) async {
              try {
                await ref
                    .read(entityDetailProvider(taskId).notifier)
                    .update(name: name, metadata: metadata);
                if (context.mounted) Navigator.of(context).pop(true);
              } on ApiException catch (e) {
                if (context.mounted) showErrorSnackbar(context, e.message);
              }
            },
          ),
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(entityDetailProvider(taskId));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Task',
      content: 'This action cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(entityDetailProvider(taskId).notifier).delete();
      onDeleted?.call();
    } on ApiException catch (e) {
      if (context.mounted) showErrorSnackbar(context, e.message);
    }
  }
}
