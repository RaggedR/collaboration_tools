import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/entity.dart';
import '../../state/providers.dart';
import '../../state/sprint_list_state.dart';
import '../../widgets/shared/entity_card.dart';
import 'sprint_create_form.dart';
import 'sprint_detail_panel.dart';

/// Sprint list grouped by temporal status.
class SprintsScreen extends ConsumerStatefulWidget {
  const SprintsScreen({super.key});

  @override
  ConsumerState<SprintsScreen> createState() => _SprintsScreenState();
}

class _SprintsScreenState extends ConsumerState<SprintsScreen> {
  String? _selectedSprintId;

  @override
  Widget build(BuildContext context) {
    final sprintsAsync = ref.watch(sprintListProvider);
    final permissions = ref.watch(permissionProvider);
    final canCreate = permissions?.canCreate('sprint') ?? false;
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text('Sprints', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => _createSprint(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Sprint'),
                ),
            ],
          ),
        ),

        Expanded(
          child: sprintsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (groups) {
              final list = _buildList(context, groups);
              if (isWide && _selectedSprintId != null) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: SprintDetailPanel(
                        sprintId: _selectedSprintId!,
                        onClose: () =>
                            setState(() => _selectedSprintId = null),
                        onDeleted: () {
                          setState(() => _selectedSprintId = null);
                          ref.invalidate(sprintListProvider);
                        },
                      ),
                    ),
                  ],
                );
              }
              return list;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, SprintGroups groups) {
    final allEmpty = groups.current.isEmpty &&
        groups.upcoming.isEmpty &&
        groups.completed.isEmpty;

    if (allEmpty) {
      return const Center(child: Text('No sprints yet'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sprintListProvider.notifier).load(),
      child: ListView(
        children: [
          if (groups.current.isNotEmpty)
            ..._section(context, 'Current', groups.current),
          if (groups.upcoming.isNotEmpty)
            ..._section(context, 'Upcoming', groups.upcoming),
          if (groups.completed.isNotEmpty)
            ..._section(context, 'Completed', groups.completed),
        ],
      ),
    );
  }

  List<Widget> _section(
      BuildContext context, String title, List<Entity> sprints) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
      ...sprints.map((s) => EntityCard(
            entity: s,
            subtitle: Text(
              '${s.metadata['start_date'] ?? '?'} \u2192 ${s.metadata['end_date'] ?? '?'}',
            ),
            onTap: () => setState(() => _selectedSprintId = s.id),
          )),
    ];
  }

  Future<void> _createSprint(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const SprintCreateForm(),
    );
    if (created == true) {
      ref.invalidate(sprintListProvider);
    }
  }
}
