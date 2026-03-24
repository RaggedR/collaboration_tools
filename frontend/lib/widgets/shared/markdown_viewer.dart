import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders markdown content with consistent styling.
class MarkdownViewer extends StatelessWidget {
  final String data;
  final bool selectable;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: data,
      selectable: selectable,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        h1: theme.textTheme.headlineMedium,
        h2: theme.textTheme.titleLarge,
        h3: theme.textTheme.titleMedium,
        p: theme.textTheme.bodyMedium,
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
      ),
    );
  }
}
