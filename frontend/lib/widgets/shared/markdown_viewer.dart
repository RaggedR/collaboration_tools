import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Renders markdown content with LaTeX math and syntax-highlighted code blocks.
///
/// LaTeX support:
///   - Inline: $...$  (rendered inline with text)
///   - Block:  $$...$$ (rendered centered on its own line)
///
/// Code blocks get syntax highlighting via highlight.js (Dart port).
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
      builders: {
        'latexInline': _LatexInlineBuilder(theme),
        'pre': _CodeBlockBuilder(isDark),
      },
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

/// Builds syntax-highlighted code blocks using highlight.js (Dart port).
class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;
  _CodeBlockBuilder(this.isDark);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    final language = _extractLanguage(element);

    final highlightTheme = isDark ? atomOneDarkTheme : atomOneLightTheme;
    final bgColor = isDark
        ? const Color(0xFF1E1E2E)
        : const Color(0xFFF5F5F5);

    // Try syntax highlighting; fall back to plain text
    List<TextSpan> spans;
    try {
      final result = language != null
          ? highlight.parse(code, language: language)
          : highlight.parse(code, autoDetection: true);
      spans = _convertNodes(result.nodes!, highlightTheme);
    } catch (_) {
      spans = [TextSpan(text: code)];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: highlightTheme['root']?.color,
            ),
            children: spans,
          ),
        ),
      ),
    );
  }

  /// Extract language from the code element's class attribute.
  /// Markdown parser sets class="language-python" on fenced code blocks.
  static String? _extractLanguage(md.Element element) {
    // The pre element contains a code child with the class attribute
    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'code') {
          final cls = child.attributes['class'];
          if (cls != null && cls.startsWith('language-')) {
            return cls.substring('language-'.length);
          }
        }
      }
    }
    return null;
  }

  /// Convert highlight.js nodes to Flutter TextSpans with theme colors.
  static List<TextSpan> _convertNodes(
      List<dynamic> nodes, Map<String, TextStyle> theme) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node is String) {
        spans.add(TextSpan(text: node));
      } else if (node.className != null) {
        final style = theme[node.className] ??
            theme[node.className!.split('.').first];
        final childSpans = node.children != null
            ? _convertNodes(node.children!, theme)
            : [TextSpan(text: node.value)];
        spans.add(TextSpan(style: style, children: childSpans));
      } else if (node.value != null) {
        spans.add(TextSpan(text: node.value));
      } else if (node.children != null) {
        spans.addAll(_convertNodes(node.children!, theme));
      }
    }
    return spans;
  }
}
