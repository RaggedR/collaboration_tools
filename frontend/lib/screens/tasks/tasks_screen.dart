import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/schema.dart';
import '../../state/providers.dart';
import '../../state/sidebar_state.dart';
import '../../state/task_board_state.dart';
import '../../widgets/kanban/kanban_board.dart';
import '../../widgets/shared/filter_bar.dart';
import '../../widgets/shared/status_badge.dart';
import 'task_create_form.dart';
import 'task_detail_panel.dart';

/// Global kanban board + filter bar. Split-pane detail panel on desktop.
///
/// Column order, labels, colors, card fields, and filter options are all
/// derived from the task entity type's ui_schema + metadata_schema.
/// Project scoping: when a project is selected in the sidebar, only
/// that project's tasks are shown.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _filterValues = <String, String?>{};
  String? _selectedTaskId;
  String? _lastProjectId;

  static const _fallbackStatusLabels = {
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
    final selectedProjectId = ref.watch(selectedProjectProvider);

    // Reload when project scope changes
    if (selectedProjectId != _lastProjectId) {
      _lastProjectId = selectedProjectId;
      Future.microtask(() => _applyFilters());
    }

    // Consume pending task selection (from cross-screen navigation).
    // Use ref.watch so we react to changes, and clear synchronously
    // to prevent duplicate consumption on rapid rebuilds.
    final pendingTaskId = ref.watch(pendingTaskSelectionProvider);
    if (pendingTaskId != null) {
      ref.read(pendingTaskSelectionProvider.notifier).state = null;
      Future.microtask(() => setState(() => _selectedTaskId = pendingTaskId));
    }

    // Get task entity type from schema
    final schemaAsync = ref.watch(schemaProvider);
    final taskType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'task', orElse: () => null);
    final ui = taskType?.uiSchema;

    // Derive column config from schema
    final statusOrder = _deriveStatusOrder(taskType);
    final statusLabels = _deriveStatusLabels(taskType);
    final columnColors = _deriveColumnColors(ui);

    // Scope label
    final sidebarData = ref.watch(sidebarDataProvider).valueOrNull;
    final scopeLabel = selectedProjectId != null
        ? sidebarData?.projects
            .where((p) => p.id == selectedProjectId)
            .map((p) => p.name)
            .firstOrNull
        : null;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with scope breadcrumb
              Row(
                children: [
                  if (scopeLabel != null) ...[
                    Text(scopeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.chevron_right,
                          size: 14, color: Color(0xFF94A3B8)),
                    ),
                  ],
                  Text('Tasks',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: () => _createTask(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Task'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFilters(taskType),
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
                        Expanded(
                          flex: 3,
                          child: _buildBoard(
                            boardState,
                            statusOrder,
                            statusLabels,
                            columnColors,
                            ui,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        Expanded(
                          flex: 2,
                          child: TaskDetailPanel(
                            taskId: _selectedTaskId!,
                            onClose: () =>
                                setState(() => _selectedTaskId = null),
                            onDeleted: () {
                              setState(() => _selectedTaskId = null);
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    )
                  : _buildBoard(
                      boardState,
                      statusOrder,
                      statusLabels,
                      columnColors,
                      ui,
                    ),
        ),
      ],
    );
  }

  List<String> _deriveStatusOrder(EntityType? taskType) {
    if (taskType == null) return defaultStatusOrder;
    final kanbanField = taskType.uiSchema.kanbanColumnField ?? 'status';
    final props =
        taskType.metadataSchema['properties'] as Map<String, dynamic>?;
    final fieldSchema = props?[kanbanField] as Map<String, dynamic>?;
    final enumValues = fieldSchema?['enum'] as List?;
    if (enumValues != null) return enumValues.cast<String>();
    return defaultStatusOrder;
  }

  Map<String, String> _deriveStatusLabels(EntityType? taskType) {
    if (taskType == null) return _fallbackStatusLabels;
    final kanbanField = taskType.uiSchema.kanbanColumnField ?? 'status';
    final props =
        taskType.metadataSchema['properties'] as Map<String, dynamic>?;
    final fieldSchema = props?[kanbanField] as Map<String, dynamic>?;
    final enumValues = fieldSchema?['enum'] as List?;
    if (enumValues == null) return _fallbackStatusLabels;
    return {
      for (final v in enumValues.cast<String>()) v: _humanize(v),
    };
  }

  Map<String, Color> _deriveColumnColors(UiSchema? ui) {
    if (ui == null) return {};
    final kanbanField = ui.kanbanColumnField ?? 'status';
    final colorMap = ui.colorsFor(kanbanField);
    return {
      for (final entry in colorMap.entries)
        entry.key: StatusBadge.parseHex(entry.value),
    };
  }

  Widget _buildFilters(EntityType? taskType) {
    final ui = taskType?.uiSchema;
    final filterFields = ui?.filters ?? ['priority'];
    final metaProps =
        taskType?.metadataSchema['properties'] as Map<String, dynamic>? ?? {};

    final filters = <FilterOption>[];
    for (final field in filterFields) {
      final fieldSchema = metaProps[field] as Map<String, dynamic>?;
      if (fieldSchema == null) continue;
      final enumValues = fieldSchema['enum'] as List?;
      if (enumValues == null) continue;
      final label = ui?.labelFor(field) ?? _humanize(field);
      filters.add(FilterOption(
        label: label,
        value: _filterValues[field],
        options: enumValues
            .cast<String>()
            .map((v) => FilterChoice(value: v, label: _humanize(v)))
            .toList(),
        onChanged: (v) {
          setState(() => _filterValues[field] = v);
          _applyFilters();
        },
      ));
    }

    return FilterBar(
      filters: filters,
      onClear: () {
        setState(() => _filterValues.clear());
        _applyFilters();
      },
    );
  }

  void _applyFilters() {
    final projectId = ref.read(selectedProjectProvider);
    final labelsRaw = _filterValues['labels'];
    ref.read(taskBoardProvider.notifier).loadTasks(
          TaskFilters(
            projectId: projectId,
            priority: _filterValues['priority'],
            status: _filterValues['status'],
            labels: labelsRaw != null ? [labelsRaw] : null,
          ),
        );
  }

  Widget _buildBoard(
    TaskBoardState boardState,
    List<String> statusOrder,
    Map<String, String> statusLabels,
    Map<String, Color> columnColors,
    UiSchema? uiSchema,
  ) {
    return KanbanBoard(
      columns: boardState.columns,
      columnOrder: statusOrder,
      columnLabels: statusLabels,
      columnColors: columnColors,
      uiSchema: uiSchema,
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
      _applyFilters();
    }
  }

  static String _humanize(String s) {
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
