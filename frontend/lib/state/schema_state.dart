import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/schema.dart';

/// Loads and caches the schema from the backend.
class SchemaNotifier extends StateNotifier<AsyncValue<Schema>> {
  final ApiClient _api;

  SchemaNotifier({required ApiClient api})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final schema = await _api.getSchema();
      state = AsyncValue.data(schema);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
