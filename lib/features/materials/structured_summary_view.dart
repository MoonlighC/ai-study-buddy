import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../auth/auth_controller.dart';
import 'material_viewer_screen.dart';
import 'original_material_repository.dart';
import 'safe_latex.dart';
import 'structured_summary.dart';
import 'summary_document_view.dart';

class StructuredSummaryView extends StatelessWidget {
  const StructuredSummaryView({
    required this.summary,
    required this.material,
    super.key,
  });
  final StructuredSummary summary;
  final StudyMaterial material;
  @override
  Widget build(BuildContext context) {
    final user = AuthScope.read(context).user;
    final canView = user != null && hasValidOriginalMetadata(material, user.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.partialExtraction.partialPages.isNotEmpty)
          _PageWarning(
            icon: Icons.warning_amber_rounded,
            label: context.l10n.analysisPartialPages,
            pages: summary.partialExtraction.partialPages,
          ),
        if (summary.partialExtraction.missingPages.isNotEmpty)
          _PageWarning(
            icon: Icons.error_outline,
            label: context.l10n.analysisMissingPages,
            pages: summary.partialExtraction.missingPages,
          ),
        if (summary.equations.any((e) => e.uncertainty))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.l10n.analysisVerifyFormulas,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final section in summary.sections) ...[
          Text(section.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final block in section.blocks) ...[
            _block(context, block, canView),
            const SizedBox(height: 8),
          ],
          _MetadataRow(
            confidence: section.confidence,
            pages: section.sourcePages,
            onPage: canView ? (page) => _openPage(context, page) : null,
          ),
          const SizedBox(height: 20),
        ],
        if (summary.keyConcepts.isNotEmpty) ...[
          for (final concept in summary.keyConcepts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      concept.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    SummaryDocumentView(markdown: concept.explanationMarkdown),
                    const SizedBox(height: 6),
                    _MetadataRow(
                      confidence: concept.confidence,
                      pages: concept.sourcePages,
                      onPage: canView
                          ? (page) => _openPage(context, page)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
        for (final warning in summary.warnings)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(warning.detail),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final page
                          in warning.sourcePages.toSet().toList()..sort())
                        ActionChip(
                          label: Text(
                            context.l10n.analysisWarningSourcePage(page),
                          ),
                          onPressed: canView
                              ? () => _openPage(context, page)
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _block(BuildContext context, SummaryBlock block, bool canView) {
    if (block is ProseBlock) {
      return SummaryDocumentView(markdown: block.markdown);
    }
    final equation = summary.equationById((block as EquationBlock).equationId);
    if (equation == null) {
      return SelectableText(context.l10n.analysisMalformedFallback);
    }
    return SafeLatex(
      equation: equation,
      sourcePage: equation.sourcePage,
      uncertainLabel: context.l10n.analysisUncertainFormula,
      sourcePageText: context.l10n.analysisSourcePageNumber(
        equation.sourcePage,
      ),
      copyLabel: context.l10n.analysisCopyFormula,
      semanticsLabel: (description) => context.l10n.analysisEquationSemantics(
        description,
        equation.sourcePage,
      ),
      onSourcePage: canView
          ? () => _openPage(context, equation.sourcePage)
          : null,
      onCopy: () => _copyEquation(context, equation.latex),
    );
  }

  Future<void> _copyEquation(BuildContext context, String latex) async {
    try {
      await Clipboard.setData(ClipboardData(text: latex));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.analysisFormulaCopied)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.analysisFormulaCopyFailed)),
      );
    }
  }

  void _openPage(BuildContext context, int page) {
    final validPage = material.kind == MaterialKind.image ? 1 : page;
    Navigator.pushNamed(
      context,
      AppRoutes.materialViewer,
      arguments: MaterialViewerArgs(
        materialId: material.id,
        kind: material.kind,
        initialPage: validPage,
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.confidence,
    required this.pages,
    this.onPage,
  });
  final double confidence;
  final List<int> pages;
  final ValueChanged<int>? onPage;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Chip(
        avatar: const Icon(Icons.verified_outlined, size: 16),
        label: Text(
          LocalizedFormatters.percentage(context.l10n, confidence * 100),
        ),
      ),
      for (final page in pages)
        ActionChip(
          label: Text(context.l10n.analysisSourcePageNumber(page)),
          onPressed: onPage == null ? null : () => onPage!(page),
        ),
      if (onPage != null && pages.isNotEmpty)
        TextButton.icon(
          onPressed: () => onPage!(pages.first),
          icon: const Icon(Icons.open_in_new),
          label: Text(context.l10n.analysisViewOriginalPage),
        ),
    ],
  );
}

class _PageWarning extends StatelessWidget {
  const _PageWarning({
    required this.icon,
    required this.label,
    required this.pages,
  });
  final IconData icon;
  final String label;
  final List<int> pages;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(pages.join(', ')),
  );
}
