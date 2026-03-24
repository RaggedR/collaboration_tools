import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Filter parameters for the task board.
class TaskFilters {
  final String? projectId;
  final String? assigneeId;
  final String? priority;
  final String? sprintId;
  final List<String>? labels;

  const TaskFilters({
    this.projectId,
    this.assigneeId,
    this.priority,
    this.sprintId,
    this.labels,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilters &&
          projectId == other.projectId &&
          assigneeId == other.assigneeId &&
          priority == other.priority &&
          sprintId == other.sprintId;

  @override
  int get hashCode => Object.hash(projectId, assigneeId, priority, sprintId);
}

/// Groups tasks by their status metadata field into kanban columns.
Map<String, List<Entity>> groupTasksByStatus(
  List<Entity> tasks,
  List<String> statusOrder,
) {
  final columns = <String, List<Entity>>{};
  for (final status in statusOrder) {
    columns[status] = [];
  }
  for (final task in tasks) {
    final status = task.metadata['status'] as String? ?? 'backlog';
    (columns[status] ??= []).add(task);
  }
  return columns;
}

/// Default status order matching the schema's task status enum.
const defaultStatusOrder = [
  'backlog',
  'todo',
  'in_progress',
  'review',
  'done',
  'archived',
];

/// State for the global task board.
class TaskBoardState {
  final List<Entity> tasks;
  final Map<String, List<Entity>> columns;
  final String? selectedTaskId;
  final bool isLoading;

  const TaskBoardState({
    this.tasks = const [],
    this.columns = const {},
    this.selectedTaskId,
    this.isLoading = false,
  });

  TaskBoardState copyWith({
    List<Entity>? tasks,
    Map<String, List<Entity>>? columns,
    String? selectedTaskId,
    bool? isLoading,
  }) {
    return TaskBoardState(
      tasks: tasks ?? this.tasks,
      columns: columns ?? this.columns,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TaskBoardNotifier extends StateNotifier<TaskBoardState> {
  final ApiClient _api;
  final List<String> statusOrder;

  TaskBoardNotifier({
    required ApiClient api,
    this.statusOrder = defaultStatusOrder,
  })  : _api = api,
        super(const TaskBoardState());

  Future<void> loadTasks([TaskFilters filters = const TaskFilters()]) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _api.listTasks(
        projectId: filters.projectId,
        assigneeId: filters.assigneeId,
        priority: filters.priority,
        sprintId: filters.sprintId,
        perPage: 200,
      );
      final columns = groupTasksByStatus(result.entities, statusOrder);
      state = TaskBoardState(
        tasks: result.entities,
        columns: columns,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Optimistic move with rollback on failure.
  ///
  /// Looks up the task's current status from state (since KanbanBoard.onDrop
  /// passes '' for fromStatus — see kanban_board.dart line 62).
  Future<void> moveTask(String taskId, String toStatus) async {
    final task = state.tasks.firstWhere((t) => t.id == taskId);
    final fromStatus = task.metadata['status'] as String? ?? 'backlog';
    if (fromStatus == toStatus) return;

    // Optimistic update.
    final previousTasks = state.tasks;
    final previousColumns = state.columns;

    final updatedTasks = state.tasks.map((t) {
      if (t.id != taskId) return t;
      return Entity(
        id: t.id,
        type: t.type,
        name: t.name,
        metadata: {...t.metadata, 'status': toStatus},
        createdBy: t.createdBy,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );
    }).toList();

    state = state.copyWith(
      tasks: updatedTasks,
      columns: groupTasksByStatus(updatedTasks, statusOrder),
    );

    try {
      await _api.updateEntity(taskId, metadata: {
        ...task.metadata,
        'status': toStatus,
      });
    } catch (_) {
      // Rollback.
      state = state.copyWith(
        tasks: previousTasks,
        columns: previousColumns,
      );
    }
  }

  void selectTask(String? taskId) {
    state = state.copyWith(selectedTaskId: taskId);
  }
}

final taskBoardProvider =
    StateNotifierProvider.autoDispose<TaskBoardNotifier, TaskBoardState>((ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = TaskBoardNotifier(api: api);
  notifier.loadTasks();
  return notifier;
});
