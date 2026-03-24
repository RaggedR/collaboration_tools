import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// A project with its nested sprints for the sidebar tree.
class ProjectNode {
  final Entity project;
  final List<Entity> sprints;
  final bool isExpanded;

  const ProjectNode({
    required this.project,
    this.sprints = const [],
    this.isExpanded = false,
  });

  ProjectNode copyWith({List<Entity>? sprints, bool? isExpanded}) {
    return ProjectNode(
      project: project,
      sprints: sprints ?? this.sprints,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

/// Full sidebar state: workspace tree, people, selection, and visibility.
class SidebarState {
  final List<Entity> workspaces;
  final List<ProjectNode> projectNodes;
  final List<Entity> people;
  final String? selectedProjectId;
  final bool isExpanded;
  final bool isLoading;

  const SidebarState({
    this.workspaces = const [],
    this.projectNodes = const [],
    this.people = const [],
    this.selectedProjectId,
    this.isExpanded = true,
    this.isLoading = false,
  });

  SidebarState copyWith({
    List<Entity>? workspaces,
    List<ProjectNode>? projectNodes,
    List<Entity>? people,
    String? Function()? selectedProjectId,
    bool? isExpanded,
    bool? isLoading,
  }) {
    return SidebarState(
      workspaces: workspaces ?? this.workspaces,
      projectNodes: projectNodes ?? this.projectNodes,
      people: people ?? this.people,
      selectedProjectId: selectedProjectId != null
          ? selectedProjectId()
          : this.selectedProjectId,
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// The name of the currently selected project, or null.
  String? get selectedProjectName {
    if (selectedProjectId == null) return null;
    for (final node in projectNodes) {
      if (node.project.id == selectedProjectId) return node.project.name;
    }
    return null;
  }
}

class SidebarNotifier extends StateNotifier<SidebarState> {
  final ApiClient _api;

  SidebarNotifier({required ApiClient api})
      : _api = api,
        super(const SidebarState());

  /// Load workspaces, projects, and people for the sidebar tree.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      // Load workspaces, projects, and people in parallel.
      final results = await Future.wait([
        _api.listEntities(type: 'workspace', perPage: 50),
        _api.listEntities(type: 'project', perPage: 200),
        _api.listEntities(type: 'person', perPage: 200),
      ]);

      final workspaces = results[0].entities;
      final projects = results[1].entities;
      final people = results[2].entities;

      // Preserve expansion state from previous load.
      final oldExpanded = <String>{
        for (final n in state.projectNodes)
          if (n.isExpanded) n.project.id,
      };

      final nodes = projects
          .map((p) => ProjectNode(
                project: p,
                isExpanded: oldExpanded.contains(p.id),
              ))
          .toList();

      state = state.copyWith(
        workspaces: workspaces,
        projectNodes: nodes,
        people: people,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle a project node open/closed and load its sprints if needed.
  Future<void> toggleProject(String projectId) async {
    final idx =
        state.projectNodes.indexWhere((n) => n.project.id == projectId);
    if (idx < 0) return;

    final node = state.projectNodes[idx];
    final newExpanded = !node.isExpanded;
    final updated = List<ProjectNode>.from(state.projectNodes);

    if (newExpanded && node.sprints.isEmpty) {
      // Fetch sprints for this project.
      try {
        final result = await _api.listEntities(
          type: 'sprint',
          relatedTo: projectId,
          relType: 'contains_sprint',
          perPage: 100,
        );
        updated[idx] = node.copyWith(
          sprints: result.entities,
          isExpanded: true,
        );
      } catch (_) {
        updated[idx] = node.copyWith(isExpanded: true);
      }
    } else {
      updated[idx] = node.copyWith(isExpanded: newExpanded);
    }

    state = state.copyWith(projectNodes: updated);
  }

  /// Select a project to scope all screens, or null to clear.
  void selectProject(String? projectId) {
    state = state.copyWith(
      selectedProjectId: () => projectId,
    );
  }

  /// Toggle sidebar visibility.
  void toggleSidebar() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }
}

final sidebarProvider =
    StateNotifierProvider<SidebarNotifier, SidebarState>((ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = SidebarNotifier(api: api);
  // Auto-load when the provider is first read (after login).
  final auth = ref.watch(authProvider);
  if (auth.isAuthenticated) {
    notifier.load();
  }
  return notifier;
});
