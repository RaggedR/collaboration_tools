import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/document_list_state.dart';
import '../../state/providers.dart';
import '../../state/sidebar_state.dart';
import '../../widgets/shared/doc_type_badge.dart';
import '../../widgets/shared/entity_card.dart';
import '../../widgets/shared/filter_bar.dart';
import '../../widgets/shared/paginated_list.dart';
import '../../widgets/shared/search_field.dart';
import 'document_create_form.dart';
import 'document_detail_panel.dart';

/// Document list with search, filters, and pagination.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String? _docTypeFilter;
  String _search = '';
  int _page = 1;
  String? _selectedDocId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadDocuments());
  }

  void _loadDocuments() {
    ref.read(documentListProvider.notifier).load(DocumentFilters(
          docType: _docTypeFilter,
          search: _search.isNotEmpty ? _search : null,
          page: _page,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentListProvider);
    final permissions = ref.watch(permissionProvider);
    final canCreate = permissions?.canCreate('document') ?? false;
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final selectedProjectName = ref.watch(
      sidebarProvider.select((s) => s.selectedProjectName),
    );

    return Column(
      children: [
        // Breadcrumb when project-scoped.
        if (selectedProjectName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  selectedProjectName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Text(' > ', style: Theme.of(context).textTheme.titleSmall),
                Text('Documents',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        // Search + filters toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: 'Search documents...',
                  onChanged: (v) {
                    _search = v;
                    _page = 1;
                    _loadDocuments();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilterBar(
                filters: [
                  FilterOption(
                    label: 'Type',
                    value: _docTypeFilter,
                    options: const [
                      FilterChoice(value: 'spec', label: 'Spec'),
                      FilterChoice(value: 'note', label: 'Note'),
                      FilterChoice(value: 'report', label: 'Report'),
                      FilterChoice(value: 'reference', label: 'Reference'),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _docTypeFilter = v;
                        _page = 1;
                      });
                      _loadDocuments();
                    },
                  ),
                ],
                onClear: () {
                  setState(() {
                    _docTypeFilter = null;
                    _page = 1;
                  });
                  _loadDocuments();
                },
              ),
              const SizedBox(width: 8),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => _createDocument(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Doc'),
                ),
            ],
          ),
        ),

        // List + optional detail panel
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (paginated) {
              // Load parent task names for visible documents.
              final docIds = paginated.entities.map((e) => e.id).toList();
              Future.microtask(() => ref
                  .read(documentParentTaskProvider.notifier)
                  .loadForDocuments(docIds));
              final parentTasks = ref.watch(documentParentTaskProvider);

              final list = PaginatedList(
                items: paginated.entities,
                total: paginated.total,
                page: paginated.page,
                perPage: paginated.perPage,
                onPageChanged: (p) {
                  setState(() => _page = p);
                  _loadDocuments();
                },
                itemBuilder: (context, entity) {
                  final docType = entity.metadata['doc_type'] as String?;
                  final parentTask = parentTasks[entity.id];
                  return EntityCard(
                    entity: entity,
                    subtitle: parentTask != null
                        ? Text('Task: $parentTask',
                            style: Theme.of(context).textTheme.bodySmall)
                        : null,
                    trailing: docType != null
                        ? DocTypeBadge(docType: docType)
                        : null,
                    onTap: () => setState(() => _selectedDocId = entity.id),
                  );
                },
              );

              if (isWide && _selectedDocId != null) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: DocumentDetailPanel(
                        documentId: _selectedDocId!,
                        onClose: () =>
                            setState(() => _selectedDocId = null),
                        onDeleted: () {
                          setState(() => _selectedDocId = null);
                          _loadDocuments();
                        },
                      ),
                    ),
                  ],
                );
              }
              return list;
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createDocument(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const DocumentCreateForm(),
    );
    if (created == true) {
      _loadDocuments();
    }
  }
}
