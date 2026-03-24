import 'dart:async';
import 'package:flutter/material.dart';

/// Debounced search text field.
class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  const SearchField({
    super.key,
    this.hint = 'Search...',
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        isDense: true,
      ),
      onChanged: _onChanged,
    );
  }
}
