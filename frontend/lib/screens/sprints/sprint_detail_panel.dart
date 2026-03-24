import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../../state/entity_detail_state.dart';
import '../../state/providers.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/shared/error_snackbar.dart';
import '../../widgets/shared/metadata_form.dart';
import '../../widgets/shared/relationship_list.dart';
import '../tasks/task_create_form.dart';

/// Detail panel for a sprint — metadata + participants + tasks + retro.
class SprintDetailPanel extends ConsumerWidget {
  final String sprintId;
  final VoidCallback? onClose;
  final VoidCallback? onDeleted;

  const SprintDetailPanel({
    super.key,
    required this.sprintId,
    this.onClose,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(entityDetailProvider(sprintId));
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
          final startDate = entity.metadata['start_date'] as String?;
          final endDate = entity.metadata['end_date'] as String?;
          final goal = entity.metadata['goal'] as String?;
          final retro = entity.metadata['retro'] as String?;
          final status = entity.metadata['status'] as String?;

          // Is the sprint finished?
          final endDt = endDate != null ? DateTime.tryParse(endDate) : null;
          final isFinished =
              endDt != null && endDt.isBefore(DateTime.now());

          // Tasks in this sprint
          final taskRels = rels
              .where((r) => r.relatedEntity.type == 'task')
              .toList();

          // Participants (via participates_in)
          final participantRels = rels
              .where((r) =>
                  r.relatedEntity.type == 'person' &&
                  r.relTypeKey == 'participates_in')
              .toList();

          // Owner
          final ownerRels = rels
              .where((r) =>
                  r.relatedEntity.type == 'person' &&
                  r.relTypeKey == 'owned_by')
              .toList();

          // Other relationships
          final otherRels = rels
              .where((r) =>
                  r.relatedEntity.type != 'task' &&
                  r.relatedEntity.type != 'person')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(entity.name,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (status != null)
                    Chip(
                      label: Text(status),
                      backgroundColor: _statusColor(status),
                    ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Dates
              if (startDate != null || endDate != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text('${startDate ?? '?'} \u2192 ${endDate ?? '?'}'),
                    if (isFinished) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Finished'),
                        backgroundColor:
                            const Color(0x2010B981),
                        labelStyle: const TextStyle(fontSize: 11),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),

              // Sprint-level goal
              if (goal != null && goal.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Sprint Goal',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(goal,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),

              // Owner
              if (ownerRels.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text('Owner: ${ownerRels.first.relatedEntity.name}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Participants with per-person goals
              Text('Participants',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (participantRels.isEmpty)
                Text('No participants yet',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                ...participantRels.map((rel) {
                  final name = rel.relatedEntity.name;
                  final participantGoal =
                      rel.metadata['goal'] as String?;
                  final reflection =
                      rel.metadata['reflection'] as String?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                child: Text(
                                    name.isNotEmpty ? name[0] : '?',
                                    style:
                                        const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                              ),
                            ],
                          ),
                          if (participantGoal != null &&
                              participantGoal.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Goal: $participantGoal',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                          ],
                          if (reflection != null &&
                              reflection.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Reflection: $reflection',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        fontStyle:
                                            FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // Sprint Goals = Tasks
              Row(
                children: [
                  Expanded(
                    child: Text('Goals (Tasks)',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (canEdit)
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Task'),
                      onPressed: () async {
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (_) => TaskCreateForm(
                              initialSprintId: sprintId),
                        );
                        if (created == true) {
                          ref.invalidate(entityDetailProvider(sprintId));
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (taskRels.isEmpty)
                Text('No tasks yet — add tasks to define sprint goals',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                ...taskRels.map((rel) => ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.check_circle_outline, size: 20),
                      title: Text(rel.relatedEntity.name),
                    )),

              // Other relationships
              if (otherRels.isNotEmpty)
                RelationshipList(
                  relationships: otherRels,
                  readOnly: !canEdit,
                ),

              // Sprint Retro
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.rate_review, size: 20),
                  const SizedBox(width: 8),
                  Text('Sprint Retro',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              if (!isFinished)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Retro unlocks after the sprint ends${endDate != null ? ' ($endDate)' : ''}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )
              else if (retro != null && retro.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Text(retro),
                )
              else if (canEdit)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Write Retro'),
                  onPressed: () =>
                      _showRetroDialog(context, ref, entity),
                )
              else
                Text('No retro written yet.',
                    style: Theme.of(context).textTheme.bodySmall),

              // Actions
              if (canEdit) ...[
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      onPressed: () =>
                          _showEditDialog(context, ref, entity),
                    ),
                    if (isFinished && (retro == null || retro.isEmpty))
                      TextButton.icon(
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Write Retro'),
                        onPressed: () =>
                            _showRetroDialog(context, ref, entity),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.delete,
                          size: 18,
                          color: Theme.of(context).colorScheme.error),
                      label: Text('Delete',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error)),
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

  Color? _statusColor(String status) {
    switch (status) {
      case 'planning':
        return const Color(0x206B7280);
      case 'active':
        return const Color(0x203B82F6);
      case 'reviewing':
        return const Color(0x20F59E0B);
      case 'completed':
        return const Color(0x2010B981);
      default:
        return null;
    }
  }

  Future<void> _showRetroDialog(
      BuildContext context, WidgetRef ref, Entity entity) async {
    final controller = TextEditingController(
        text: entity.metadata['retro'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sprint Retro'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'What went well? What could improve? Key learnings?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref
            .read(entityDetailProvider(sprintId).notifier)
            .update(metadata: {
          ...entity.metadata,
          'retro': controller.text,
        });
      } on ApiException catch (e) {
        if (context.mounted) showErrorSnackbar(context, e.message);
      }
    }
    controller.dispose();
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Entity entity) async {
    final schemaAsync = ref.read(schemaProvider);
    final sprintType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'sprint', orElse: () => null);

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Sprint'),
        content: SizedBox(
          width: 400,
          child: MetadataForm(
            metadataSchema: sprintType?.metadataSchema ?? {},
            initialName: entity.name,
            initialValues: Map<String, dynamic>.from(entity.metadata),
            onSubmit: (name, metadata) async {
              try {
                await ref
                    .read(entityDetailProvider(sprintId).notifier)
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
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Sprint',
      content: 'This action cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(entityDetailProvider(sprintId).notifier).delete();
      onDeleted?.call();
    } on ApiException catch (e) {
      if (context.mounted) showErrorSnackbar(context, e.message);
    }
  }
}
