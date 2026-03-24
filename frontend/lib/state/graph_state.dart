import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/graph.dart';
import 'providers.dart';

/// Parameters for graph query.
class GraphParams {
  final String? rootId;
  final int? depth;
  final List<String>? types;

  const GraphParams({this.rootId, this.depth, this.types});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphParams &&
          rootId == other.rootId &&
          depth == other.depth;

  @override
  int get hashCode => Object.hash(rootId, depth);
}

class GraphNotifier extends StateNotifier<AsyncValue<Graph>> {
  final ApiClient _api;

  GraphNotifier({required ApiClient api})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load(GraphParams params) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.getGraph(
        rootId: params.rootId,
        depth: params.depth,
        types: params.types,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final graphProvider =
    StateNotifierProvider.autoDispose<GraphNotifier, AsyncValue<Graph>>((ref) {
  final api = ref.watch(apiClientProvider);
  return GraphNotifier(api: api);
});
