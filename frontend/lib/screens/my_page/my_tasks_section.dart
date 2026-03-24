import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../state/task_board_state.dart';
import '../../widgets/kanban/kanban_board.dart';

/// Kanban board section for a person's tasks.
class MyTasksSection extends StatelessWidget {
  final List<Entity> tasks;
  final void Function(String taskId, String fromStatus, String toStatus)?
      onStatusChange;
  final void Function(Entity task)? onTaskTap;
  final bool readOnly;

  const MyTasksSection({
    super.key,
    required this.tasks,
    this.onStatusChange,
    this.onTaskTap,
    this.readOnly = false,
  });

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
    final columns = groupTasksByStatus(tasks, defaultStatusOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 400,
          child: KanbanBoard(
            columns: columns,
            columnOrder: defaultStatusOrder,
            columnLabels: _statusLabels,
            onStatusChange: onStatusChange,
            onTaskTap: onTaskTap,
            readOnly: readOnly,
            collapsedColumns: const ['archived'],
          ),
        ),
      ],
    );
  }
}
