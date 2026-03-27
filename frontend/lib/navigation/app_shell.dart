import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/models/entity.dart';
import '../state/providers.dart';
import '../state/sidebar_state.dart';

/// Responsive app shell with three-column layout (Outline-style).
///
/// Desktop (>900px): 72px icon rail + 200px collapsible sidebar + content.
/// Mobile: Bottom nav bar + slide-out drawer.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    _Destination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'My Page',
        path: '/my-page'),
    _Destination(
        icon: Icons.check_circle_outline,
        selectedIcon: Icons.check_circle,
        label: 'Tasks',
        path: '/tasks'),
    _Destination(
        icon: Icons.timer_outlined,
        selectedIcon: Icons.timer,
        label: 'Sprints',
        path: '/sprints'),
    _Destination(
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
        label: 'Documents',
        path: '/documents'),
  ];

  // Wireframe chrome colors
  static const _navRailBgLight = Color(0xFFF1F5F9);
  static const _navRailBgDark = Color(0xFF1E293B);
  static const _mutedText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isWide) {
      final isExpanded = ref.watch(sidebarExpandedProvider);
      return Scaffold(
        body: Row(
          children: [
            _buildNavRail(context, ref, isDark),
            if (isExpanded) _SidebarPanel(isDark: isDark),
            // Subtle border between sidebar and content
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon, size: 22),
                  selectedIcon: Icon(d.selectedIcon, size: 22),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }

  /// 72px Outline-style icon rail.
  Widget _buildNavRail(BuildContext context, WidgetRef ref, bool isDark) {
    final selectedIndex = navigationShell.currentIndex;
    final accentColor = Theme.of(context).colorScheme.primary;
    final isExpanded = ref.watch(sidebarExpandedProvider);

    return Container(
      width: 72,
      color: isDark ? _navRailBgDark : _navRailBgLight,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Nav items
          ..._destinations.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final isSelected = i == selectedIndex;

            return Tooltip(
              message: d.label,
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 400),
              child: InkWell(
                onTap: () => navigationShell.goBranch(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Icon(
                    isSelected ? d.selectedIcon : d.icon,
                    size: 22,
                    color: isSelected ? accentColor : _mutedText,
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Sidebar toggle
          Tooltip(
            message: isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
            preferBelow: false,
            child: InkWell(
              onTap: () => ref.read(sidebarExpandedProvider.notifier).state =
                  !isExpanded,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 48,
                margin: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  isExpanded ? Icons.chevron_left : Icons.chevron_right,
                  size: 20,
                  color: _mutedText,
                ),
              ),
            ),
          ),

          // Logout
          Tooltip(
            message: 'Sign out',
            preferBelow: false,
            child: InkWell(
              onTap: () => ref.read(authProvider.notifier).logout(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 48,
                margin: const EdgeInsets.only(bottom: 16),
                child: const Icon(Icons.logout, size: 20, color: _mutedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _projectStatusColor(String? status) {
    switch (status) {
      case 'active':
        return const Color(0xFF3B82F6); // blue
      case 'paused':
        return const Color(0xFF94A3B8); // gray
      case 'completed':
        return const Color(0xFF10B981); // green
      case 'archived':
        return const Color(0xFFD1D5DB); // light gray
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

/// Sidebar panel extracted as ConsumerStatefulWidget to track collapsed sections.
class _SidebarPanel extends ConsumerStatefulWidget {
  final bool isDark;

  const _SidebarPanel({required this.isDark});

  @override
  ConsumerState<_SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends ConsumerState<_SidebarPanel> {
  final _collapsedSections = <String>{};

  static const _navRailBgLight = Color(0xFFF1F5F9);
  static const _navRailBgDark = Color(0xFF1E293B);
  static const _mutedText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final schemaAsync = ref.watch(schemaProvider);
    final sidebarAsync = ref.watch(sidebarDataProvider);
    final selectedProjectId = ref.watch(selectedProjectProvider);
    final selectedWorkspaceId = ref.watch(selectedWorkspaceProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isAdmin;
    final accentColor = Theme.of(context).colorScheme.primary;
    final appName = schemaAsync.valueOrNull?.app.name ?? 'CMS';

    // Find selected workspace name
    final workspaces = sidebarAsync.valueOrNull?.workspaces ?? [];
    final selectedWorkspace = selectedWorkspaceId != null
        ? workspaces
            .where((w) => w.id == selectedWorkspaceId)
            .firstOrNull
        : null;
    final headerLabel = selectedWorkspace?.name ?? appName;

    return Container(
      width: 200,
      color: isDark ? _navRailBgDark : _navRailBgLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workspace selector dropdown
          PopupMenuButton<String>(
            tooltip: 'Switch workspace',
            offset: const Offset(0, 44),
            onSelected: (value) {
              if (value == '__create__') {
                _showCreateWorkspaceDialog(context);
              } else if (value == '__all__') {
                ref.read(selectedWorkspaceProvider.notifier).state = null;
                ref.read(selectedProjectProvider.notifier).state = null;
              } else {
                ref.read(selectedWorkspaceProvider.notifier).state = value;
                ref.read(selectedProjectProvider.notifier).state = null;
              }
            },
            itemBuilder: (context) => [
              // "All workspaces" option
              const PopupMenuItem<String>(
                value: '__all__',
                child: Text('All Workspaces'),
              ),
              const PopupMenuDivider(),
              // Workspace list
              ...workspaces.map((ws) => PopupMenuItem<String>(
                    value: ws.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ws.name,
                            style: TextStyle(
                              fontWeight: ws.id == selectedWorkspaceId
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _confirmDeleteWorkspace(context, ws);
                            },
                            tooltip: 'Delete workspace',
                          ),
                      ],
                    ),
                  )),
              // Admin: create workspace option
              if (isAdmin) ...[
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: '__create__',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 8),
                      Text('New Workspace'),
                    ],
                  ),
                ),
              ],
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.workspaces_outlined,
                        size: 14, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headerLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.unfold_more, size: 16, color: _mutedText),
                ],
              ),
            ),
          ),

          Divider(
              height: 1,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

          // Sidebar content
          Expanded(
            child: sidebarAsync.when(
              loading: () => const Center(
                child:
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load',
                    style: TextStyle(color: _mutedText, fontSize: 12)),
              ),
              data: (data) => ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Projects section
                  _buildSectionHeader('PROJECTS', isDark),
                  if (!_collapsedSections.contains('PROJECTS'))
                    ...data.projects.map((project) {
                      final status = project.metadata['status'] as String?;
                      final isSelected = selectedProjectId == project.id;
                      return _SidebarItem(
                        label: project.name,
                        statusDot: AppShell._projectStatusColor(status),
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedProjectProvider.notifier).state =
                              isSelected ? null : project.id;
                        },
                        accentColor: accentColor,
                        isDark: isDark,
                      );
                    }),

                  const SizedBox(height: 12),

                  // People section
                  _buildSectionHeader('PEOPLE', isDark),
                  if (!_collapsedSections.contains('PEOPLE'))
                    ...data.people.map((person) {
                      return _SidebarItem(
                        label: person.name,
                        icon: Icons.person_outline,
                        isSelected: false,
                        onTap: () =>
                            GoRouter.of(context).go('/person/${person.id}'),
                        accentColor: accentColor,
                        isDark: isDark,
                      );
                    }),
                ],
              ),
            ),
          ),

          // Collapse button
          Divider(
              height: 1,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          InkWell(
            onTap: () =>
                ref.read(sidebarExpandedProvider.notifier).state = false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 16, color: _mutedText),
                  const SizedBox(width: 8),
                  Text('Collapse',
                      style: TextStyle(fontSize: 12, color: _mutedText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, bool isDark) {
    final isCollapsed = _collapsedSections.contains(label);
    final headerColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => setState(() {
        if (isCollapsed) {
          _collapsedSections.remove(label);
        } else {
          _collapsedSections.add(label);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: headerColor,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 16, color: headerColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateWorkspaceDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Engineering',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final api = ref.read(apiClientProvider);
              await api.createEntity(
                type: 'workspace',
                name: name,
                metadata: {
                  if (descController.text.trim().isNotEmpty)
                    'description': descController.text.trim(),
                },
              );
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      ref.invalidate(sidebarDataProvider);
    }
  }

  Future<void> _confirmDeleteWorkspace(
      BuildContext context, Entity workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workspace'),
        content: Text(
            'Delete "${workspace.name}"? Projects in this workspace will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = ref.read(apiClientProvider);
      await api.deleteEntity(workspace.id);
      // If this was the selected workspace, clear selection
      if (ref.read(selectedWorkspaceProvider) == workspace.id) {
        ref.read(selectedWorkspaceProvider.notifier).state = null;
      }
      ref.invalidate(sidebarDataProvider);
    }
  }
}

/// Individual sidebar item with optional status dot or icon.
class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? statusDot;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isDark;

  const _SidebarItem({
    required this.label,
    this.icon,
    this.statusDot,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: isSelected
            ? BoxDecoration(color: accentColor.withValues(alpha: 0.08))
            : null,
        child: Row(
          children: [
            if (statusDot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusDot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.white54 : _AppShellColors.muted)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
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

class _AppShellColors {
  static const muted = Color(0xFF64748B);
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;

  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });
}
