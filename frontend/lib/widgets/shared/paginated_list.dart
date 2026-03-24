import 'package:flutter/material.dart';

/// A list of items with prev/next pagination controls and "showing X-Y of Z".
class PaginatedList<T> extends StatelessWidget {
  final List<T> items;
  final int total;
  final int page;
  final int perPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final ValueChanged<int> onPageChanged;

  const PaginatedList({
    super.key,
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    required this.itemBuilder,
    required this.onPageChanged,
  });

  int get _totalPages => (total / perPage).ceil();
  int get _start => total == 0 ? 0 : (page - 1) * perPage + 1;
  int get _end => (_start + items.length - 1).clamp(0, total);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No items'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
                ),
        ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $_start\u2013$_end of $total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                    ),
                    Text('$page / $_totalPages'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page < _totalPages
                          ? () => onPageChanged(page + 1)
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
}
