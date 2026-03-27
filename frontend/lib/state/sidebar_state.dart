import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Whether the sidebar panel is expanded (desktop only).
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// Currently selected workspace ID.
/// null = show all projects (no workspace filter).
final selectedWorkspaceProvider = StateProvider<String?>((ref) => null);

/// Currently selected project ID for scoping content views.
/// null = show all (no project filter).
final selectedProjectProvider = StateProvider<String?>((ref) => null);

/// Pending entity selection — set before navigating to another screen,
/// consumed on arrival so the target screen opens the detail panel.
final pendingDocumentSelectionProvider = StateProvider<String?>((ref) => null);
final pendingTaskSelectionProvider = StateProvider<String?>((ref) => null);

/// Data needed by the sidebar: workspaces, projects, and people.
class SidebarData {
  final List<Entity> workspaces;
  final List<Entity> projects;
  final List<Entity> people;

  const SidebarData({
    required this.workspaces,
    required this.projects,
    required this.people,
  });
}

final sidebarDataProvider =
    FutureProvider.autoDispose<SidebarData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final workspaceId = ref.watch(selectedWorkspaceProvider);

  final results = await Future.wait([
    api.listEntities(type: 'workspace', perPage: 100),
    // When a workspace is selected, only fetch its projects
    workspaceId != null
        ? api.listEntities(
            type: 'project',
            relatedTo: workspaceId,
            relType: 'contains_project',
            perPage: 100,
          )
        : api.listEntities(type: 'project', perPage: 100),
    api.listEntities(type: 'person', perPage: 100),
  ]);
  return SidebarData(
    workspaces: results[0].entities,
    projects: results[1].entities,
    people: results[2].entities,
  );
});
