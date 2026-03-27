import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/entity.dart';
import '../../state/sidebar_state.dart';

/// Expandable workspace → project → sprint tree for the sidebar.
///
/// Each workspace shows its name as a header, with projects nested below.
/// Projects have status dots and expand to show sprints.
class ProjectTree extends ConsumerWidget {
  const ProjectTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebar = ref.watch(sidebarProvider);

    if (sidebar.workspaceNodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'NO WORKSPACES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final wsNode in sidebar.workspaceNodes) ...[
          // Workspace name header — click to clear project filter.
          InkWell(
            onTap: () =>
                ref.read(sidebarProvider.notifier).selectProject(null),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                wsNode.workspace.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ),

          // Projects nested under this workspace.
          ...wsNode.projects
              .map((node) => _ProjectItem(node: node)),
        ],
      ],
    );
  }
}

class _ProjectItem extends ConsumerWidget {
  final ProjectNode node;

  const _ProjectItem({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        ref.watch(sidebarProvider).selectedProjectId == node.project.id;
    final status = node.project.metadata['status'] as String?;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () =>
              ref.read(sidebarProvider.notifier).selectProject(node.project.id),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: isSelected
                ? BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Row(
              children: [
                // Expand/collapse toggle.
                GestureDetector(
                  onTap: () => ref
                      .read(sidebarProvider.notifier)
                      .toggleProject(node.project.id),
                  child: AnimatedRotation(
                    turns: node.isExpanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Status dot.
                _StatusDot(status: status, isProject: true),
                const SizedBox(width: 8),
                // Project name.
                Expanded(
                  child: Text(
                    node.project.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? accentColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Nested sprints (when expanded).
        if (node.isExpanded)
          ...node.sprints.map((sprint) => _SprintItem(sprint: sprint)),
      ],
    );
  }
}

class _SprintItem extends StatelessWidget {
  final Entity sprint;

  const _SprintItem({required this.sprint});

  @override
  Widget build(BuildContext context) {
    final status = sprint.metadata['status'] as String?;

    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            _StatusDot(status: status, isProject: false),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sprint.name,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status indicator dot.
///
/// Projects: filled blue (active), outline gray (paused), check green (completed)
/// Sprints: filled green (active), outline gray (planning), check blue (completed)
class _StatusDot extends StatelessWidget {
  final String? status;
  final bool isProject;

  const _StatusDot({this.status, required this.isProject});

  @override
  Widget build(BuildContext context) {
    final (Color color, bool filled, bool check) = _resolveStatus();

    if (check) {
      return Icon(Icons.check_circle, size: 10, color: color);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
        shape: BoxShape.circle,
      ),
    );
  }

  (Color, bool, bool) _resolveStatus() {
    if (isProject) {
      switch (status) {
        case 'active':
          return (const Color(0xFF3B82F6), true, false);
        case 'paused':
          return (const Color(0xFF94A3B8), false, false);
        case 'completed':
          return (const Color(0xFF10B981), false, true);
        default:
          return (const Color(0xFF94A3B8), false, false);
      }
    } else {
      switch (status) {
        case 'active':
          return (const Color(0xFF10B981), true, false);
        case 'planning':
          return (const Color(0xFF94A3B8), false, false);
        case 'completed':
          return (const Color(0xFF3B82F6), false, true);
        default:
          return (const Color(0xFF94A3B8), false, false);
      }
    }
  }
}
