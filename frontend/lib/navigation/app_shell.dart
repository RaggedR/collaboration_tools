import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/providers.dart';

/// Responsive app shell with NavigationRail (desktop) / BottomNavigationBar (mobile).
///
/// Desktop: 72px icon-only nav rail (Outline-style) with tooltips.
/// Mobile: Bottom navigation bar with 5 icons.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    _Destination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'My Page', path: '/my-page'),
    _Destination(icon: Icons.check_circle_outline, selectedIcon: Icons.check_circle, label: 'Tasks', path: '/tasks'),
    _Destination(icon: Icons.timer_outlined, selectedIcon: Icons.timer, label: 'Sprints', path: '/sprints'),
    _Destination(icon: Icons.description_outlined, selectedIcon: Icons.description, label: 'Documents', path: '/documents'),
    _Destination(icon: Icons.hub_outlined, selectedIcon: Icons.hub, label: 'Graph', path: '/graph'),
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
      return Scaffold(
        body: Row(
          children: [
            _buildNavRail(context, ref, isDark),
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

  /// Builds the 72px Outline-style nav rail.
  Widget _buildNavRail(BuildContext context, WidgetRef ref, bool isDark) {
    final selectedIndex = navigationShell.currentIndex;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 72,
      color: isDark ? _navRailBgDark : _navRailBgLight,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Navigation items
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

          // User menu / logout at bottom
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
