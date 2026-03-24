import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Temporal grouping of sprints.
class SprintGroups {
  final List<Entity> current;
  final List<Entity> upcoming;
  final List<Entity> completed;

  const SprintGroups({
    this.current = const [],
    this.upcoming = const [],
    this.completed = const [],
  });
}

class SprintListNotifier extends StateNotifier<AsyncValue<SprintGroups>> {
  final ApiClient _api;

  SprintListNotifier({required ApiClient api})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.listSprints(perPage: 200);
      final now = DateTime.now();
      final current = <Entity>[];
      final upcoming = <Entity>[];
      final completed = <Entity>[];

      for (final sprint in result.entities) {
        final startStr = sprint.metadata['start_date'] as String?;
        final endStr = sprint.metadata['end_date'] as String?;
        final start = startStr != null ? DateTime.tryParse(startStr) : null;
        final end = endStr != null ? DateTime.tryParse(endStr) : null;

        if (end != null && end.isBefore(now)) {
          completed.add(sprint);
        } else if (start != null && start.isAfter(now)) {
          upcoming.add(sprint);
        } else {
          current.add(sprint);
        }
      }

      state = AsyncValue.data(SprintGroups(
        current: current,
        upcoming: upcoming,
        completed: completed,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sprintListProvider =
    StateNotifierProvider.autoDispose<SprintListNotifier, AsyncValue<SprintGroups>>(
        (ref) {
  final api = ref.watch(apiClientProvider);
  final notifier = SprintListNotifier(api: api);
  notifier.load();
  return notifier;
});
