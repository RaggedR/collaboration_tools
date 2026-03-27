import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Filter parameters for the task board.
class TaskFilters {
  final String? projectId;
  final String? assigneeId;
  final String? priority;
  final String? status;
  final String? sprintId;
  final List<String>? labels;

  const TaskFilters({
    this.projectId,
    this.assigneeId,
    this.priority,
    this.status,
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
          status == other.status &&
          sprintId == other.sprintId &&
          _listEquals(labels, other.labels);

  @override
  int get hashCode =>
      Object.hash(projectId, assigneeId, priority, status, sprintId, labels);

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
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
        status: filters.status,
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
    print('[moveTask] called: taskId=$taskId toStatus=$toStatus');
    final task = state.tasks.firstWhere((t) => t.id == taskId);
    final fromStatus = task.metadata['status'] as String? ?? 'backlog';
    print('[moveTask] ${task.name}: $fromStatus -> $toStatus');
    if (fromStatus == toStatus) {
      print('[moveTask] same status, skipping');
      return;
    }

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
    print('[moveTask] optimistic update applied');

    try {
      final result = await _api.updateEntity(taskId, metadata: {
        ...task.metadata,
        'status': toStatus,
      });
      print('[moveTask] API success: new status=${result.metadata['status']}');

      // Auto-archive linked documents when task moves to "archived"
      if (toStatus == 'archived') {
        _autoArchiveLinkedDocuments(taskId);
      }
    } catch (e) {
      // Rollback on API failure.
      print('[moveTask] API FAILED: $e');
      state = state.copyWith(
        tasks: previousTasks,
        columns: previousColumns,
      );
    }
  }

  /// When a task is archived, check if all tasks linked to its documents
  /// are also archived. If so, archive the document too.
  Future<void> _autoArchiveLinkedDocuments(String taskId) async {
    try {
      final taskDetail = await _api.getEntity(taskId);
      final docRels = taskDetail.relationships.where(
        (r) => r.relTypeKey == 'contains_doc' && r.relatedEntity.type == 'document',
      );

      for (final docRel in docRels) {
        final docId = docRel.relatedEntity.id;
        // Find all tasks linked to this document
        final linkedTasks = await _api.listEntities(
          type: 'task',
          relatedTo: docId,
          relType: 'contains_doc',
          perPage: 200,
        );
        final allArchived = linkedTasks.entities.every(
          (t) => t.metadata['status'] == 'archived',
        );
        if (allArchived) {
          final docDetail = await _api.getEntity(docId);
          await _api.updateEntity(docId, metadata: {
            ...docDetail.entity.metadata,
            'status': 'archived',
          });
          print('[autoArchive] Archived document: ${docRel.relatedEntity.name}');
        }
      }
    } catch (e) {
      // Best-effort — don't break the UI if auto-archive fails
      print('[autoArchive] Error: $e');
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
