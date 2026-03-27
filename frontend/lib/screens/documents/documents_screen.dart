import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/entity.dart';
import '../../state/document_list_state.dart';
import '../../state/providers.dart';
import '../../state/sidebar_state.dart';
import '../../widgets/shared/doc_type_badge.dart';
import '../../widgets/shared/filter_bar.dart';
import '../../widgets/shared/search_field.dart';
import 'document_create_form.dart';
import 'document_detail_panel.dart';

/// Document list — Outline-style generous rows with search, filters, pagination.
///
/// Steal from Outline: Each row is 60px+, generous padding, 16px semibold title,
/// 13px muted metadata. Doc type as colored pill. Hairline dividers, not cards.
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
  String? _lastProjectId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadDocuments());
  }

  void _loadDocuments() {
    final projectId = ref.read(selectedProjectProvider);
    ref.read(documentListProvider.notifier).load(DocumentFilters(
          docType: _docTypeFilter,
          search: _search.isNotEmpty ? _search : null,
          projectId: projectId,
          page: _page,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentListProvider);
    final permissions = ref.watch(permissionProvider);
    final canCreate = permissions?.canCreate('document') ?? false;
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final selectedProjectId = ref.watch(selectedProjectProvider);

    // Reload when project scope changes
    if (selectedProjectId != _lastProjectId) {
      _lastProjectId = selectedProjectId;
      Future.microtask(() {
        _page = 1;
        _loadDocuments();
      });
    }

    // Consume pending document selection (from cross-screen navigation).
    // Use ref.watch so we react to changes, and clear synchronously
    // to prevent duplicate consumption on rapid rebuilds.
    final pendingDocId = ref.watch(pendingDocumentSelectionProvider);
    if (pendingDocId != null) {
      ref.read(pendingDocumentSelectionProvider.notifier).state = null;
      Future.microtask(() => setState(() => _selectedDocId = pendingDocId));
    }

    // Scope label
    final sidebarData = ref.watch(sidebarDataProvider).valueOrNull;
    final scopeLabel = selectedProjectId != null
        ? sidebarData?.projects
            .where((p) => p.id == selectedProjectId)
            .map((p) => p.name)
            .firstOrNull
        : null;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with scope breadcrumb
              Row(
                children: [
                  if (scopeLabel != null) ...[
                    Text(scopeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.chevron_right,
                          size: 14, color: Color(0xFF94A3B8)),
                    ),
                  ],
                  Text('Documents',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: () => _createDocument(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Doc'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Search + filter row
              Row(
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
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Document list + optional detail panel
        Expanded(
          child: docsAsync.when(
            loading: () => _buildSkeletonList(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (paginated) {
              if (paginated.entities.isEmpty) {
                return _buildEmptyState(context, canCreate);
              }

              final list = _buildDocumentList(paginated, context);

              if (isWide && _selectedDocId != null) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: list),
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).dividerColor,
                    ),
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

  /// Outline-style document list with generous rows.
  Widget _buildDocumentList(PaginatedEntities paginated, BuildContext context) {
    final totalPages = (paginated.total / paginated.perPage).ceil();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: paginated.entities.length,
            itemBuilder: (context, i) {
              final doc = paginated.entities[i];
              return _DocumentRow(
                entity: doc,
                isSelected: doc.id == _selectedDocId,
                onTap: () => setState(() => _selectedDocId = doc.id),
                showDivider: i < paginated.entities.length - 1,
              );
            },
          ),
        ),
        if (paginated.total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${paginated.total == 0 ? 0 : (paginated.page - 1) * paginated.perPage + 1}'
                  '\u2013${((paginated.page - 1) * paginated.perPage + paginated.entities.length).clamp(0, paginated.total)}'
                  ' of ${paginated.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 1
                          ? () {
                              setState(() => _page--);
                              _loadDocuments();
                            }
                          : null,
                    ),
                    Text('$_page / $totalPages'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _page < totalPages
                          ? () {
                              setState(() => _page++);
                              _loadDocuments();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Skeleton loading — Outline style.
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 6,
      itemBuilder: (context, i) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final shimmerColor =
            isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
        final shimmerHighlight =
            isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200 + (i * 20.0 % 60),
                height: 16,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Empty state — Outline style: centered text, no clipart.
  Widget _buildEmptyState(BuildContext context, bool canCreate) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No documents yet.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Create your first document to get started.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (canCreate) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _createDocument(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Document'),
            ),
          ],
        ],
      ),
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

/// A single document row — Outline-style generous spacing.
///
/// 60px+ height, 16px semibold title, 13px muted metadata line.
/// Hairline divider between rows, no card borders.
class _DocumentRow extends StatelessWidget {
  final Entity entity;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDivider;

  const _DocumentRow({
    required this.entity,
    required this.isSelected,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final docType = entity.metadata['doc_type'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Format date
    final dateStr = _formatDate(entity.updatedAt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.06)
              : Colors.transparent,
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F5F9),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Document icon
            Icon(
              Icons.description_outlined,
              size: 20,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 14),

            // Title + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (docType != null) ...[
                        DocTypeBadge(docType: docType),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(Icons.chevron_right, size: 18, color: accentColor),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
