import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/providers.dart';
import '../state/sidebar_state.dart';
import '../widgets/sidebar/project_tree.dart';
import '../widgets/sidebar/people_list.dart';

/// Responsive app shell with NavigationRail + Sidebar (desktop) /
/// BottomNavigationBar + Drawer (mobile).
///
/// Desktop (>900px): 72px icon-only nav rail + 200px sidebar + content area.
/// Mobile (<900px): Bottom navigation bar with 4 icons; sidebar as drawer.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    _Destination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'My Page', path: '/my-page'),
    _Destination(icon: Icons.check_circle_outline, selectedIcon: Icons.check_circle, label: 'Tasks', path: '/tasks'),
    _Destination(icon: Icons.timer_outlined, selectedIcon: Icons.timer, label: 'Sprints', path: '/sprints'),
    _Destination(icon: Icons.description_outlined, selectedIcon: Icons.description, label: 'Documents', path: '/documents'),
  ];

  // Wireframe color constants
  static const _navRailBgLight = Color(0xFFF1F5F9);
  static const _navRailBgDark = Color(0xFF1E293B);
  static const _mutedText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isWide) {
      return _buildDesktop(context, ref, isDark);
    }
    return _buildMobile(context, ref, isDark);
  }

  Widget _buildDesktop(BuildContext context, WidgetRef ref, bool isDark) {
    final sidebarExpanded = ref.watch(sidebarProvider).isExpanded;

    return Scaffold(
      body: Row(
        children: [
          _buildNavRail(context, ref, isDark, sidebarExpanded),
          if (sidebarExpanded) _buildSidebar(context, ref, isDark),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, WidgetRef ref, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: _buildProjectScopeChip(context, ref),
        toolbarHeight: 48,
      ),
      drawer: _buildDrawer(context, ref, isDark),
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

  /// 72px Outline-style nav rail. When sidebar is collapsed, shows an expand
  /// button at the bottom instead of the logout button position.
  Widget _buildNavRail(
      BuildContext context, WidgetRef ref, bool isDark, bool sidebarExpanded) {
    final selectedIndex = navigationShell.currentIndex;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 72,
      color: isDark ? _navRailBgDark : _navRailBgLight,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Navigation items.
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

          // Sidebar toggle.
          if (!sidebarExpanded)
            Tooltip(
              message: 'Expand sidebar',
              preferBelow: false,
              child: InkWell(
                onTap: () =>
                    ref.read(sidebarProvider.notifier).toggleSidebar(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 4),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _mutedText,
                  ),
                ),
              ),
            ),

          // User menu / logout at bottom.
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
                child: const Icon(
                  Icons.logout,
                  size: 20,
                  color: _mutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 200px sidebar with project tree, people list, and collapse toggle.
  Widget _buildSidebar(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      width: 200,
      color: isDark ? _navRailBgDark : _navRailBgLight,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12),
              children: const [
                ProjectTree(),
                SizedBox(height: 16),
                PeopleList(),
              ],
            ),
          ),
          // Collapse button at bottom.
          InkWell(
            onTap: () =>
                ref.read(sidebarProvider.notifier).toggleSidebar(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, size: 16, color: _mutedText),
                  const SizedBox(width: 4),
                  Text(
                    'Collapse',
                    style: TextStyle(
                      fontSize: 12,
                      color: _mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile drawer containing the same sidebar content.
  Widget _buildDrawer(BuildContext context, WidgetRef ref, bool isDark) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 12),
                children: const [
                  ProjectTree(),
                  SizedBox(height: 16),
                  PeopleList(),
                ],
              ),
            ),
            // Logout in drawer.
            ListTile(
              leading: const Icon(Icons.logout, size: 20),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the currently scoped project name as a chip in the mobile app bar.
  Widget? _buildProjectScopeChip(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(sidebarProvider).selectedProjectName;
    if (projectName == null) return null;

    return GestureDetector(
      onTap: () => ref.read(sidebarProvider.notifier).selectProject(null),
      child: Chip(
        label: Text(projectName, style: const TextStyle(fontSize: 13)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () =>
            ref.read(sidebarProvider.notifier).selectProject(null),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
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
