import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Selectable, theme-aware rendering for server-generated summary prose.
/// Structured mathematical blocks are intentionally deferred to Phase C.
class SummaryDocumentView extends StatelessWidget {
  const SummaryDocumentView({
    required this.markdown,
    this.collapsed = false,
    super.key,
  });

  final String markdown;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final document = MarkdownBody(
      data: _withoutHtml(markdown),
      selectable: true,
      // Summary Markdown is untrusted model output. Returning an inert widget
      // here prevents every image source from reaching an ImageProvider.
      imageBuilder: (_, _, _) => const SizedBox.shrink(),
      // Links are styled and selectable but deliberately not opened in Phase A.
      onTapLink: (_, _, _) {},
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: bodyStyle,
        h1: theme.textTheme.headlineSmall,
        h2: theme.textTheme.titleLarge,
        h3: theme.textTheme.titleMedium,
        blockSpacing: 10,
        listIndent: 24,
        a: bodyStyle?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
    if (!collapsed) return document;

    final lineHeight = MediaQuery.textScalerOf(context).scale(14) * 1.45;
    return SizedBox(
      key: const ValueKey('collapsed-summary-markdown'),
      height: lineHeight * 14,
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: document,
        ),
      ),
    );
  }

  String _withoutHtml(String value) {
    return value.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }
}
