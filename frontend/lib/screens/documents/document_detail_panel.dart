import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_client.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../../state/entity_detail_state.dart';
import '../../state/providers.dart';
import '../../state/sidebar_state.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/shared/doc_type_badge.dart';
import '../../widgets/shared/error_snackbar.dart';
import '../../widgets/shared/file_viewer.dart';
import '../../widgets/shared/markdown_viewer.dart';
import '../../widgets/shared/metadata_form.dart';
import '../../widgets/shared/relationship_list.dart';

/// Detail panel for a single document.
class DocumentDetailPanel extends ConsumerWidget {
  final String documentId;
  final VoidCallback? onClose;
  final VoidCallback? onDeleted;

  const DocumentDetailPanel({
    super.key,
    required this.documentId,
    this.onClose,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(entityDetailProvider(documentId));
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
          final docType = entity.metadata['doc_type'] as String?;
          final url = entity.metadata['url'] as String?;

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
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Doc type badge
              if (docType != null) DocTypeBadge(docType: docType),
              const SizedBox(height: 12),

              // File viewer for URL (images, PDFs, links)
              if (url != null) ...[
                FileViewer(url: url),
                const SizedBox(height: 16),
              ],

              // Markdown body content
              if (entity.body != null && entity.body!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                MarkdownViewer(data: entity.body!),
                const SizedBox(height: 16),
              ],

              // Relationships
              RelationshipList(
                relationships: rels,
                readOnly: !canEdit,
                onEntityTap: (entity) =>
                    _navigateToEntity(context, ref, entity),
              ),

              // Actions
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
                      icon: Icon(Icons.delete,
                          size: 18,
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
      BuildContext context, WidgetRef ref, Entity entity) async {
    final schemaAsync = ref.read(schemaProvider);
    final docEntityType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'document', orElse: () => null);

    final bodyController = TextEditingController(text: entity.body ?? '');
    final metadataFormKey = GlobalKey<MetadataFormState>();

    await showDialog<bool>(
      context: context,
      builder: (context) {
        bool showPreview = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Document'),
            content: SizedBox(
              width: 500,
              height: MediaQuery.of(context).size.height * 0.7,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetadataForm(
                      key: metadataFormKey,
                      metadataSchema: docEntityType?.metadataSchema ?? {},
                      uiSchema: docEntityType?.uiSchema,
                      initialName: entity.name,
                      initialValues:
                          Map<String, dynamic>.from(entity.metadata),
                      showSubmitButton: false,
                      onSubmit: (name, metadata) async {
                        try {
                          await ref
                              .read(entityDetailProvider(documentId).notifier)
                              .update(
                                name: name,
                                body: bodyController.text.isEmpty
                                    ? null
                                    : bodyController.text,
                                metadata: metadata,
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            showErrorSnackbar(context, e.message);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Body (Markdown)',
                            style: Theme.of(context).textTheme.titleSmall),
                        const Spacer(),
                        TextButton.icon(
                          icon: Icon(showPreview
                              ? Icons.edit
                              : Icons.visibility),
                          label:
                              Text(showPreview ? 'Edit' : 'Preview'),
                          onPressed: () =>
                              setState(() => showPreview = !showPreview),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (showPreview)
                      Container(
                        padding: const EdgeInsets.all(12),
                        constraints:
                            const BoxConstraints(minHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: bodyController.text.isEmpty
                            ? Text('Nothing to preview',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant))
                            : MarkdownViewer(data: bodyController.text),
                      )
                    else
                      TextField(
                        controller: bodyController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText: 'Write markdown content...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          metadataFormKey.currentState?.submit(),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    bodyController.dispose();
  }

  void _navigateToEntity(
      BuildContext context, WidgetRef ref, RelatedEntity entity) {
    switch (entity.type) {
      case 'person':
        GoRouter.of(context).go('/person/${entity.id}');
      case 'task':
        ref.read(pendingTaskSelectionProvider.notifier).state = entity.id;
        GoRouter.of(context).go('/tasks');
      case 'sprint':
        GoRouter.of(context).go('/sprints');
      case 'document':
        ref.read(pendingDocumentSelectionProvider.notifier).state = entity.id;
        GoRouter.of(context).go('/documents');
      case 'project':
        GoRouter.of(context).go('/tasks');
      default:
        GoRouter.of(context).go('/my-page');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Document',
      content: 'This action cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(entityDetailProvider(documentId).notifier).delete();
      onDeleted?.call();
    } on ApiException catch (e) {
      if (context.mounted) showErrorSnackbar(context, e.message);
    }
  }
}
