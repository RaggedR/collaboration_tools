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

/// Maps document IDs to their parent task names (via contains_doc relationship).
class DocumentParentTaskNotifier extends StateNotifier<Map<String, String>> {
  final ApiClient _api;

  DocumentParentTaskNotifier({required ApiClient api})
      : _api = api,
        super(const {});

  /// Load parent task names for a list of document IDs.
  Future<void> loadForDocuments(List<String> docIds) async {
    if (docIds.isEmpty) return;

    final parentMap = <String, String>{};
    try {
      // Fetch all contains_doc relationships and match them to our docs.
      final rels = await _api.listRelationships(
        relType: 'contains_doc',
        perPage: 500,
      );
      // contains_doc: source=task, target=document.
      // Build a map of docId → taskId.
      final docToTaskId = <String, String>{};
      for (final rel in rels) {
        if (docIds.contains(rel.targetEntityId)) {
          docToTaskId[rel.targetEntityId] = rel.sourceEntityId;
        }
      }

      // Fetch task names for matched task IDs.
      final taskIds = docToTaskId.values.toSet();
      for (final taskId in taskIds) {
        try {
          final detail = await _api.getEntity(taskId);
          final taskName = detail.entity.name;
          // Map all docs that belong to this task.
          for (final entry in docToTaskId.entries) {
            if (entry.value == taskId) {
              parentMap[entry.key] = taskName;
            }
          }
        } catch (_) {
          // Task may have been deleted; skip.
        }
      }
    } catch (_) {
      // Non-critical — just means we can't show parent tasks.
    }
    state = parentMap;
  }
}

final documentParentTaskProvider = StateNotifierProvider.autoDispose<
    DocumentParentTaskNotifier, Map<String, String>>((ref) {
  final api = ref.watch(apiClientProvider);
  return DocumentParentTaskNotifier(api: api);
});
