import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// State for a person's My Page — tasks, sprints, and documents fetched in parallel.
class MyPageData {
  final Entity? person;
  final List<Entity> tasks;
  final List<Entity> sprints;
  final List<Entity> documents;

  const MyPageData({
    this.person,
    this.tasks = const [],
    this.sprints = const [],
    this.documents = const [],
  });
}

class MyPageNotifier extends StateNotifier<AsyncValue<MyPageData>> {
  final ApiClient _api;
  final String personId;

  MyPageNotifier({required ApiClient api, required this.personId})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      // Fetch all three lists in parallel.
      final results = await Future.wait([
        _api.getEntity(personId),
        _api.listTasks(assigneeId: personId),
        _api.listSprints(participantId: personId),
        _api.listDocuments(authorId: personId),
      ]);

      final person = (results[0] as EntityWithRelationships).entity;
      final tasks = (results[1] as PaginatedEntities).entities;
      final sprints = (results[2] as PaginatedEntities).entities;
      final documents = (results[3] as PaginatedEntities).entities;

      state = AsyncValue.data(MyPageData(
        person: person,
        tasks: tasks,
        sprints: sprints,
        documents: documents,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider family keyed by personId.
final myPageProvider = StateNotifierProvider.autoDispose
    .family<MyPageNotifier, AsyncValue<MyPageData>, String>((ref, personId) {
  final api = ref.watch(apiClientProvider);
  final notifier = MyPageNotifier(api: api, personId: personId);
  notifier.load();
  return notifier;
});
