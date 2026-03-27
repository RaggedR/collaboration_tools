import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Whether the sidebar panel is expanded (desktop only).
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// Currently selected project ID for scoping content views.
/// null = show all (no project filter).
final selectedProjectProvider = StateProvider<String?>((ref) => null);

/// Data needed by the sidebar: projects and people.
class SidebarData {
  final List<Entity> projects;
  final List<Entity> people;

  const SidebarData({required this.projects, required this.people});
}

final sidebarDataProvider =
    FutureProvider.autoDispose<SidebarData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final results = await Future.wait([
    api.listEntities(type: 'project', perPage: 100),
    api.listEntities(type: 'person', perPage: 100),
  ]);
  return SidebarData(
    projects: results[0].entities,
    people: results[1].entities,
  );
});
