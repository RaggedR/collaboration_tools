import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/entity.dart';
import '../../state/providers.dart';
import '../../state/sprint_list_state.dart';
import 'sprint_create_form.dart';
import 'sprint_detail_panel.dart';

/// Sprint list grouped by temporal status.
///
/// Visual design stolen from Accountability Tracker: collapsible user-card
/// pattern with colored headers, chevron toggles, and progressive disclosure.
/// Sprint cards show status indicator, name, date range, goal, and progress.
class SprintsScreen extends ConsumerStatefulWidget {
  const SprintsScreen({super.key});

  @override
  ConsumerState<SprintsScreen> createState() => _SprintsScreenState();
}

class _SprintsScreenState extends ConsumerState<SprintsScreen> {
  String? _selectedSprintId;
  final _collapsedSections = <String>{};

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Sprints',
                  style: Theme.of(context).textTheme.headlineMedium),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No sprints yet',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sprintListProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (groups.current.isNotEmpty)
            _buildSection(context, 'CURRENT', groups.current, _currentColor),
          if (groups.upcoming.isNotEmpty)
            _buildSection(context, 'UPCOMING', groups.upcoming, _upcomingColor),
          if (groups.completed.isNotEmpty)
            _buildSection(
                context, 'COMPLETED', groups.completed, _completedColor),
        ],
      ),
    );
  }

  // Accountability-tracker-style section colors
  static const _currentColor = Color(0xFF10B981);
  static const _upcomingColor = Color(0xFF64748B);
  static const _completedColor = Color(0xFF3B82F6);

  /// Builds a collapsible section — like the accountability tracker's
  /// user-card pattern: colored header with chevron toggle.
  Widget _buildSection(
    BuildContext context,
    String title,
    List<Entity> sprints,
    Color accentColor,
  ) {
    final isCollapsed = _collapsedSections.contains(title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header — tap to collapse/expand
          InkWell(
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsedSections.remove(title);
              } else {
                _collapsedSections.add(title);
              }
            }),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sprints.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        size: 20, color: accentColor),
                  ),
                ],
              ),
            ),
          ),

          // Sprint cards — hidden when collapsed
          if (!isCollapsed) ...[
            const SizedBox(height: 8),
            ...sprints.map((sprint) => _buildSprintCard(
                  context, sprint, accentColor, title)),
          ],
        ],
      ),
    );
  }

  /// Builds an individual sprint card — accountability-tracker style.
  Widget _buildSprintCard(
    BuildContext context,
    Entity sprint,
    Color accentColor,
    String section,
  ) {
    final isSelected = sprint.id == _selectedSprintId;
    final startDate = sprint.metadata['start_date'] as String?;
    final endDate = sprint.metadata['end_date'] as String?;
    final goal = sprint.metadata['goal'] as String?;
    final status = sprint.metadata['status'] as String?;

    // Status indicator
    final IconData statusIcon;
    switch (section) {
      case 'CURRENT':
        statusIcon = Icons.circle;
        break;
      case 'COMPLETED':
        statusIcon = Icons.check_circle;
        break;
      default:
        statusIcon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedSprintId = sprint.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ??
                Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Status icon + name + date range
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sprint.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (startDate != null || endDate != null)
                    Text(
                      '${startDate ?? '?'} \u2192 ${endDate ?? '?'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),

              // Row 2: Status chip + goal
              if (status != null || (goal != null && goal.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _humanize(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (goal != null && goal.isNotEmpty)
                      Expanded(
                        child: Text(
                          goal,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  static String _humanize(String s) {
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
