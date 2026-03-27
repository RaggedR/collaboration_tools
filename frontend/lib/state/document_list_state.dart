import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/entity.dart';
import 'providers.dart';

/// Filter parameters for the document list.
class DocumentFilters {
  final String? docType;
  final String? search;
  final String? projectId;
  final int page;

  const DocumentFilters({this.docType, this.search, this.projectId, this.page = 1});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentFilters &&
          docType == other.docType &&
          search == other.search &&
          projectId == other.projectId &&
          page == other.page;

  @override
  int get hashCode => Object.hash(docType, search, projectId, page);
}

class DocumentListNotifier extends StateNotifier<AsyncValue<PaginatedEntities>> {
  final ApiClient _api;

  DocumentListNotifier({required ApiClient api})
      : _api = api,
        super(const AsyncValue.loading());

  Future<void> load(DocumentFilters filters) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.listDocuments(
        docType: filters.docType,
        projectId: filters.projectId,
        page: filters.page,
      );
      // Client-side search filtering (backend search applies to all entities).
      if (filters.search != null && filters.search!.isNotEmpty) {
        final query = filters.search!.toLowerCase();
        final filtered = result.entities
            .where((e) => e.name.toLowerCase().contains(query))
            .toList();
        state = AsyncValue.data(PaginatedEntities(
          entities: filtered,
          total: filtered.length,
          page: result.page,
          perPage: result.perPage,
        ));
      } else {
        state = AsyncValue.data(result);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final documentListProvider = StateNotifierProvider.autoDispose<
    DocumentListNotifier, AsyncValue<PaginatedEntities>>((ref) {
  final api = ref.watch(apiClientProvider);
  return DocumentListNotifier(api: api);
});
