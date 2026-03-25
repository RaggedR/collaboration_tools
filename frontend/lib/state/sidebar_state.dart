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

/// A workspace with its nested projects.
class WorkspaceNode {
  final Entity workspace;
  final List<ProjectNode> projects;

  const WorkspaceNode({
    required this.workspace,
    this.projects = const [],
  });

  WorkspaceNode copyWith({List<ProjectNode>? projects}) {
    return WorkspaceNode(
      workspace: workspace,
      projects: projects ?? this.projects,
    );
  }
}

/// Full sidebar state: workspace tree, people, selection, and visibility.
class SidebarState {
  final List<WorkspaceNode> workspaceNodes;
  final List<Entity> people;
  final String? selectedProjectId;
  final bool isExpanded;
  final bool isLoading;

  const SidebarState({
    this.workspaceNodes = const [],
    this.people = const [],
    this.selectedProjectId,
    this.isExpanded = true,
    this.isLoading = false,
  });

  SidebarState copyWith({
    List<WorkspaceNode>? workspaceNodes,
    List<Entity>? people,
    String? Function()? selectedProjectId,
    bool? isExpanded,
    bool? isLoading,
  }) {
    return SidebarState(
      workspaceNodes: workspaceNodes ?? this.workspaceNodes,
      people: people ?? this.people,
      selectedProjectId: selectedProjectId != null
          ? selectedProjectId()
          : this.selectedProjectId,
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// All project nodes across all workspaces (flattened).
  List<ProjectNode> get allProjectNodes =>
      workspaceNodes.expand((ws) => ws.projects).toList();

  /// The name of the currently selected project, or null.
  String? get selectedProjectName {
    if (selectedProjectId == null) return null;
    for (final node in allProjectNodes) {
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

  /// Load workspaces, their projects (via contains_project), and people.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      // Preserve expansion state from previous load.
      final oldExpanded = <String>{
        for (final n in state.allProjectNodes)
          if (n.isExpanded) n.project.id,
      };

      // Load workspaces and people in parallel.
      final results = await Future.wait([
        _api.listEntities(type: 'workspace', perPage: 50),
        _api.listEntities(type: 'person', perPage: 200),
      ]);

      final workspaces = results[0].entities;
      final people = results[1].entities;

      // For each workspace, load its projects via the contains_project relationship.
      final wsNodes = <WorkspaceNode>[];
      for (final ws in workspaces) {
        final projectResult = await _api.listEntities(
          type: 'project',
          relatedTo: ws.id,
          relType: 'contains_project',
          perPage: 200,
        );
        final projectNodes = projectResult.entities
            .map((p) => ProjectNode(
                  project: p,
                  isExpanded: oldExpanded.contains(p.id),
                ))
            .toList();
        wsNodes.add(WorkspaceNode(workspace: ws, projects: projectNodes));
      }

      state = state.copyWith(
        workspaceNodes: wsNodes,
        people: people,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle a project node open/closed and load its sprints if needed.
  Future<void> toggleProject(String projectId) async {
    // Find which workspace contains this project.
    for (var wi = 0; wi < state.workspaceNodes.length; wi++) {
      final ws = state.workspaceNodes[wi];
      final pi = ws.projects.indexWhere((n) => n.project.id == projectId);
      if (pi < 0) continue;

      final node = ws.projects[pi];
      final newExpanded = !node.isExpanded;
      final updatedProjects = List<ProjectNode>.from(ws.projects);

      if (newExpanded && node.sprints.isEmpty) {
        // Fetch sprints for this project.
        try {
          final result = await _api.listEntities(
            type: 'sprint',
            relatedTo: projectId,
            relType: 'contains_sprint',
            perPage: 100,
          );
          updatedProjects[pi] = node.copyWith(
            sprints: result.entities,
            isExpanded: true,
          );
        } catch (_) {
          updatedProjects[pi] = node.copyWith(isExpanded: true);
        }
      } else {
        updatedProjects[pi] = node.copyWith(isExpanded: newExpanded);
      }

      final updatedWs = List<WorkspaceNode>.from(state.workspaceNodes);
      updatedWs[wi] = ws.copyWith(projects: updatedProjects);
      state = state.copyWith(workspaceNodes: updatedWs);
      return;
    }
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
