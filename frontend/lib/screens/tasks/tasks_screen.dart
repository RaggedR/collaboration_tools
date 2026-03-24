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

/// Global kanban board + filter bar. Split-pane on desktop.
///
/// Column order, labels, colors, card fields, and filter options are all
/// derived from the task entity type's ui_schema + metadata_schema.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  /// Active filter values keyed by field name (e.g., {"priority": "high"}).
  final _filterValues = <String, String?>{};
  String? _selectedTaskId;

  /// Hardcoded fallback — used only when schema hasn't loaded yet.
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
    final selectedProjectName = ref.watch(
      sidebarProvider.select((s) => s.selectedProjectName),
    );

    // Reload tasks when project scope changes.
    ref.listen<String?>(
      sidebarProvider.select((s) => s.selectedProjectId),
      (prev, next) {
        if (prev != next) _applyFilters();
      },
    );

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

    return Column(
      children: [
        // Breadcrumb when project-scoped.
        if (selectedProjectName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  selectedProjectName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Text(' > ', style: Theme.of(context).textTheme.titleSmall),
                Text('Tasks', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _buildFilters(taskType),
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

  /// Derives column order from the task status enum in metadata_schema.
  List<String> _deriveStatusOrder(EntityType? taskType) {
    if (taskType == null) return defaultStatusOrder;

    // Find the kanban column field from ui_schema
    final kanbanField = taskType.uiSchema.kanbanColumnField ?? 'status';

    // Get enum values from metadata_schema
    final props =
        taskType.metadataSchema['properties'] as Map<String, dynamic>?;
    final fieldSchema = props?[kanbanField] as Map<String, dynamic>?;
    final enumValues = fieldSchema?['enum'] as List?;

    if (enumValues != null) return enumValues.cast<String>();
    return defaultStatusOrder;
  }

  /// Derives column labels from the ui_schema label or humanized enum values.
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

  /// Derives column header colors from ui_schema.
  Map<String, Color> _deriveColumnColors(UiSchema? ui) {
    if (ui == null) return {};

    final kanbanField = ui.kanbanColumnField ?? 'status';
    final colorMap = ui.colorsFor(kanbanField);

    return {
      for (final entry in colorMap.entries)
        entry.key: StatusBadge.parseHex(entry.value),
    };
  }

  /// Builds schema-driven filter bar.
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
      if (enumValues == null) continue; // Only enum fields become filters

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
    final metadata = <String, dynamic>{};
    for (final entry in _filterValues.entries) {
      if (entry.value != null) metadata[entry.key] = entry.value;
    }
    final projectId = ref.read(sidebarProvider).selectedProjectId;
    ref.read(taskBoardProvider.notifier).loadTasks(
          TaskFilters(projectId: projectId, metadata: metadata),
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
      ref.read(taskBoardProvider.notifier).loadTasks();
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
