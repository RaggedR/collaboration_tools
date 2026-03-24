import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_client.dart';
import '../../api/models/entity.dart';
import '../../state/my_page_state.dart';
import '../../state/providers.dart';
import '../../widgets/shared/error_snackbar.dart';
import 'my_tasks_section.dart';
import 'my_sprints_section.dart';
import 'my_documents_section.dart';

/// My Page screen — shows a person's tasks, sprints, and documents.
///
/// When viewing your own page, kanban drag-and-drop is enabled.
/// When viewing another person's page (via /person/:id), it's read-only
/// unless you're an admin.
class MyPageScreen extends ConsumerWidget {
  final String? personId;

  const MyPageScreen({super.key, this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final effectiveId = personId ?? auth.personEntityId;

    if (effectiveId == null) {
      return const Center(child: Text('No person linked to this account'));
    }

    final isOwnPage = effectiveId == auth.personEntityId;
    final canEdit = isOwnPage || auth.isAdmin;
    final pageState = ref.watch(myPageProvider(effectiveId));

    return pageState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.read(myPageProvider(effectiveId).notifier).load(),
        child: ListView(
          children: [
            // Person header
            _PersonHeader(person: data.person, isOwnPage: isOwnPage),

            // Tasks kanban
            MyTasksSection(
              tasks: data.tasks,
              readOnly: !canEdit,
              onStatusChange: canEdit
                  ? (taskId, _, toStatus) async {
                      try {
                        final api = ref.read(apiClientProvider);
                        final task =
                            data.tasks.firstWhere((t) => t.id == taskId);
                        await api.updateEntity(taskId, metadata: {
                          ...task.metadata,
                          'status': toStatus,
                        });
                        ref.invalidate(myPageProvider(effectiveId));
                      } on ApiException catch (e) {
                        if (context.mounted) showErrorSnackbar(context, e.message);
                      }
                    }
                  : null,
              onTaskTap: (task) => context.go('/tasks'),
            ),

            // Sprints
            MySprintsSection(
              sprints: data.sprints,
              onSprintTap: (_) => context.go('/sprints'),
            ),

            // Documents
            MyDocumentsSection(
              documents: data.documents,
              onDocumentTap: (_) => context.go('/documents'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonHeader extends StatelessWidget {
  final Entity? person;
  final bool isOwnPage;

  const _PersonHeader({this.person, required this.isOwnPage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = person?.name ?? 'Unknown';
    final role = person?.metadata['role'] as String?;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOwnPage ? 'My Page' : name,
                style: theme.textTheme.headlineSmall,
              ),
              if (role != null)
                Text(role, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
