import 'package:flutter/material.dart';

/// Semi-transparent overlay with centered spinner.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
