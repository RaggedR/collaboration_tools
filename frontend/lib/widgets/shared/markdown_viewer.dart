import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Renders markdown content with LaTeX math and styled code blocks.
///
/// LaTeX support:
///   - Inline: $...$  (rendered inline with text)
///   - Block:  $$...$$ (rendered centered on its own line)
///
/// Code blocks get a dark background with monospace font.
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

    // Split on block-level LaTeX ($$...$$) to render them separately
    final segments = _splitBlockLatex(data);

    if (segments.length == 1 && !segments[0].isLatex) {
      // No block LaTeX — render as single markdown block with inline LaTeX
      return _buildMarkdown(context, theme, data);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg.isLatex) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  seg.text.trim(),
                  textStyle: theme.textTheme.bodyLarge,
                  onErrorFallback: (err) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      seg.text.trim(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return _buildMarkdown(context, theme, seg.text);
      }).toList(),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, String text) {
    final isDark = theme.brightness == Brightness.dark;
    final codeBg = isDark
        ? const Color(0xFF1E1E2E)
        : theme.colorScheme.surfaceContainerHighest;
    final codeColor = isDark ? const Color(0xFFCDD6F4) : null;

    return MarkdownBody(
      data: text,
      selectable: selectable,
      inlineSyntaxes: [_LatexInlineSyntax()],
      builders: {'latexInline': _LatexInlineBuilder(theme)},
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
          color: codeColor,
          backgroundColor: codeBg,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        tableBorder: TableBorder.all(
          color: theme.dividerColor,
          width: 1,
        ),
        tableHead: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
      ),
    );
  }

  /// Splits text on $$...$$ block delimiters.
  static List<_Segment> _splitBlockLatex(String text) {
    final segments = <_Segment>[];
    final pattern = RegExp(r'\$\$([\s\S]*?)\$\$');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_Segment(text.substring(lastEnd, match.start), false));
      }
      segments.add(_Segment(match.group(1)!, true));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_Segment(text.substring(lastEnd), false));
    }

    if (segments.isEmpty) {
      segments.add(_Segment(text, false));
    }

    return segments;
  }
}

class _Segment {
  final String text;
  final bool isLatex;
  const _Segment(this.text, this.isLatex);
}

/// Custom inline syntax for $...$ LaTeX expressions.
class _LatexInlineSyntax extends md.InlineSyntax {
  // Match $...$ but not $$ (which is block-level)
  _LatexInlineSyntax() : super(r'\$([^\$\n]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.text('latexInline', match[1]!);
    parser.addNode(el);
    return true;
  }
}

/// Builds inline LaTeX elements using flutter_math_fork.
class _LatexInlineBuilder extends MarkdownElementBuilder {
  final ThemeData theme;
  _LatexInlineBuilder(this.theme);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      textStyle: preferredStyle ?? theme.textTheme.bodyMedium,
      onErrorFallback: (err) => Text(
        '\$${element.textContent}\$',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
