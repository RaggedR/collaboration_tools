import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/entity.dart';
import '../../state/entity_detail_state.dart';
import '../../state/providers.dart';
import '../../state/sidebar_state.dart';
import '../../state/sprint_list_state.dart';
import 'sprint_create_form.dart';
import 'sprint_detail_panel.dart';

/// Sprint list grouped by temporal status.
///
/// Each sprint expands to show one card per participant with their
/// personal goal and reflection. Collapsible sections with chevron toggles.
class SprintsScreen extends ConsumerStatefulWidget {
  const SprintsScreen({super.key});

  @override
  ConsumerState<SprintsScreen> createState() => _SprintsScreenState();
}

class _SprintsScreenState extends ConsumerState<SprintsScreen> {
  String? _selectedSprintId;
  final _collapsedSections = <String>{};
  String? _lastProjectId;

  @override
  Widget build(BuildContext context) {
    final sprintsAsync = ref.watch(sprintListProvider);
    final permissions = ref.watch(permissionProvider);
    final canCreate = permissions?.canCreate('sprint') ?? false;
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final selectedProjectId = ref.watch(selectedProjectProvider);

    // Reload when project scope changes
    if (selectedProjectId != _lastProjectId) {
      _lastProjectId = selectedProjectId;
      Future.microtask(
          () => ref.read(sprintListProvider.notifier).load(projectId: selectedProjectId));
    }

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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
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
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(
                      flex: 2,
                      child: SprintDetailPanel(
                        sprintId: _selectedSprintId!,
                        onClose: () =>
                            setState(() => _selectedSprintId = null),
                        onDeleted: () {
                          setState(() => _selectedSprintId = null);
                          ref.read(sprintListProvider.notifier).load(
                              projectId: ref.read(selectedProjectProvider));
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
            Text('No sprints yet.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Create your first sprint to get started.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sprintListProvider.notifier).load(
          projectId: ref.read(selectedProjectProvider)),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          if (groups.current.isNotEmpty)
            _buildSection(context, 'CURRENT', groups.current, _currentColor),
          if (groups.upcoming.isNotEmpty)
            _buildSection(
                context, 'UPCOMING', groups.upcoming, _upcomingColor),
          if (groups.completed.isNotEmpty)
            _buildSection(
                context, 'COMPLETED', groups.completed, _completedColor),
        ],
      ),
    );
  }

  static const _currentColor = Color(0xFF10B981);
  static const _upcomingColor = Color(0xFF64748B);
  static const _completedColor = Color(0xFF3B82F6);

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          if (!isCollapsed) ...[
            const SizedBox(height: 8),
            ...sprints.map((sprint) =>
                _buildSprintWithParticipants(context, sprint, accentColor, title)),
          ],
        ],
      ),
    );
  }

  /// Sprint card that loads participant data and shows per-user cards.
  Widget _buildSprintWithParticipants(
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sprint header card
          InkWell(
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
                  if (status != null ||
                      (goal != null && goal.isNotEmpty)) ...[
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

          // Participant cards (loaded from entity detail)
          const SizedBox(height: 4),
          Consumer(
            builder: (context, ref, _) {
              final detailAsync = ref.watch(entityDetailProvider(sprint.id));
              return detailAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: LinearProgressIndicator(),
                ),
                error: (e, st) => const SizedBox.shrink(),
                data: (detail) {
                  final participants = detail.relationships
                      .where((r) =>
                          r.relatedEntity.type == 'person' &&
                          r.relTypeKey == 'participates_in')
                      .toList();

                  if (participants.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      children: participants.map((rel) {
                        final name = rel.relatedEntity.name;
                        final participantGoal =
                            rel.metadata['goal'] as String?;
                        final reflection =
                            rel.metadata['reflection'] as String?;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      accentColor.withValues(alpha: 0.15),
                                  child: Text(
                                    name.isNotEmpty ? name[0] : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      if (participantGoal != null &&
                                          participantGoal.isNotEmpty)
                                        Text(
                                          participantGoal,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (reflection != null &&
                                          reflection.isNotEmpty)
                                        Text(
                                          reflection,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  fontStyle:
                                                      FontStyle.italic),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createSprint(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const SprintCreateForm(),
    );
    if (created == true) {
      ref.read(sprintListProvider.notifier).load(
          projectId: ref.read(selectedProjectProvider));
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
