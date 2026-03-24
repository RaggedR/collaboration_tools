import 'package:flutter/material.dart';

/// A horizontal row of dropdown filters with a clear button.
class FilterBar extends StatelessWidget {
  final List<FilterOption> filters;
  final VoidCallback? onClear;

  const FilterBar({
    super.key,
    required this.filters,
    this.onClear,
  });

  bool get _hasActiveFilters => filters.any((f) => f.value != null);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButton<String>(
                  value: filter.value,
                  hint: Text(filter.label),
                  underline: const SizedBox.shrink(),
                  items: filter.options
                      .map((o) => DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ))
                      .toList(),
                  onChanged: filter.onChanged,
                ),
              )),
          if (_hasActiveFilters && onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

/// Configuration for a single dropdown filter.
class FilterOption {
  final String label;
  final String? value;
  final List<FilterChoice> options;
  final ValueChanged<String?> onChanged;

  const FilterOption({
    required this.label,
    this.value,
    required this.options,
    required this.onChanged,
  });
}

/// A single choice within a filter dropdown.
class FilterChoice {
  final String value;
  final String label;

  const FilterChoice({required this.value, required this.label});
}
