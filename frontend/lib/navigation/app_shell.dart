import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/providers.dart';

/// Responsive app shell with NavigationRail (desktop) / BottomNavigationBar (mobile).
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    _Destination(icon: Icons.person, label: 'My Page', path: '/my-page'),
    _Destination(icon: Icons.check_circle, label: 'Tasks', path: '/tasks'),
    _Destination(icon: Icons.timer, label: 'Sprints', path: '/sprints'),
    _Destination(icon: Icons.description, label: 'Documents', path: '/documents'),
    _Destination(icon: Icons.hub, label: 'Graph', path: '/graph'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context, ref),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (i) => navigationShell.goBranch(i),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            )
          : navigationShell,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (i) => navigationShell.goBranch(i),
              destinations: _destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.icon),
                        label: d.label,
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildTitle(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(schemaProvider);
    return Text(
      schemaAsync.valueOrNull?.app.name ?? 'Collaboration Tools',
    );
  }
}

class _Destination {
  final IconData icon;
  final String label;
  final String path;

  const _Destination({
    required this.icon,
    required this.label,
    required this.path,
  });
}
