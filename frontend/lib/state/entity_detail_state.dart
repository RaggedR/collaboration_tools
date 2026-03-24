import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

class EntityDetailNotifier
    extends StateNotifier<AsyncValue<EntityWithRelationships>> {
  final ApiClient _api;
  final String entityId;

  EntityDetailNotifier({required ApiClient api, required this.entityId})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.getEntity(entityId);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update({
    String? name,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.updateEntity(entityId,
          name: name, body: body, metadata: metadata);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete() async {
    await _api.deleteEntity(entityId);
  }
}

/// Provider family keyed by entity ID.
final entityDetailProvider = StateNotifierProvider.autoDispose.family<
    EntityDetailNotifier,
    AsyncValue<EntityWithRelationships>,
    String>((ref, entityId) {
  final api = ref.watch(apiClientProvider);
  final notifier = EntityDetailNotifier(api: api, entityId: entityId);
  notifier.load();
  return notifier;
});
