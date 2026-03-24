import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../state/task_board_state.dart';
import '../../widgets/kanban/kanban_board.dart';
import '../../widgets/shared/filter_bar.dart';
import 'task_create_form.dart';
import 'task_detail_panel.dart';

/// Global kanban board + filter bar. Split-pane on desktop.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _priorityFilter;
  String? _selectedTaskId;

  static const _statusLabels = {
    'backlog': 'Backlog',
    'todo': 'To Do',
    'in_progress': 'In Progress',
    'review': 'Review',
    'done': 'Done',
    'archived': 'Archived',
  };

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(taskBoardProvider);
    final permissions = ref.watch(permissionProvider);
    final canCreate = permissions?.canCreate('task') ?? false;
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: FilterBar(
                  filters: [
                    FilterOption(
                      label: 'Priority',
                      value: _priorityFilter,
                      options: const [
                        FilterChoice(value: 'low', label: 'Low'),
                        FilterChoice(value: 'medium', label: 'Medium'),
                        FilterChoice(value: 'high', label: 'High'),
                        FilterChoice(value: 'urgent', label: 'Urgent'),
                      ],
                      onChanged: (v) {
                        setState(() => _priorityFilter = v);
                        ref.read(taskBoardProvider.notifier).loadTasks(
                              TaskFilters(priority: v),
                            );
                      },
                    ),
                  ],
                  onClear: () {
                    setState(() => _priorityFilter = null);
                    ref.read(taskBoardProvider.notifier).loadTasks();
                  },
                ),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => _createTask(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                ),
            ],
          ),
        ),

        // Board + optional detail panel
        Expanded(
          child: boardState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : isWide && _selectedTaskId != null
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: _buildBoard(boardState)),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 2,
                          child: TaskDetailPanel(
                            taskId: _selectedTaskId!,
                            onClose: () =>
                                setState(() => _selectedTaskId = null),
                            onDeleted: () {
                              setState(() => _selectedTaskId = null);
                              ref.read(taskBoardProvider.notifier).loadTasks();
                            },
                          ),
                        ),
                      ],
                    )
                  : _buildBoard(boardState),
        ),
      ],
    );
  }

  Widget _buildBoard(TaskBoardState boardState) {
    return KanbanBoard(
      columns: boardState.columns,
      columnOrder: defaultStatusOrder,
      columnLabels: _statusLabels,
      onStatusChange: (taskId, _, toStatus) {
        ref.read(taskBoardProvider.notifier).moveTask(taskId, toStatus);
      },
      onTaskTap: (task) => setState(() => _selectedTaskId = task.id),
    );
  }

  Future<void> _createTask(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const TaskCreateForm(),
    );
    if (created == true) {
      ref.read(taskBoardProvider.notifier).loadTasks();
    }
  }
}
