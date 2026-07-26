import 'package:flutter/foundation.dart';

const supportedStructuredSummarySchemaVersion = 1;

enum SummaryDisplay { inline, block }

enum PageModeKind { text, visual }

sealed class SummaryBlock {
  const SummaryBlock(this.display);
  final SummaryDisplay display;
}

class ProseBlock extends SummaryBlock {
  const ProseBlock({required this.markdown, required SummaryDisplay display})
    : super(display);
  final String markdown;
}

class EquationBlock extends SummaryBlock {
  const EquationBlock({
    required this.equationId,
    required SummaryDisplay display,
  }) : super(display);
  final String equationId;
}

class StructuredSection {
  const StructuredSection({
    required this.id,
    required this.title,
    required this.blocks,
    required this.sourcePages,
    required this.confidence,
  });
  final String id, title;
  final List<SummaryBlock> blocks;
  final List<int> sourcePages;
  final double confidence;
}

class KeyConcept {
  const KeyConcept({
    required this.title,
    required this.explanationMarkdown,
    required this.sourcePages,
    required this.confidence,
  });
  final String title, explanationMarkdown;
  final List<int> sourcePages;
  final double confidence;
}

class Equation {
  const Equation({
    required this.id,
    required this.latex,
    required this.explanationMarkdown,
    required this.sourcePage,
    required this.display,
    required this.confidence,
    required this.uncertainty,
  });
  final String id, latex, explanationMarkdown;
  final int sourcePage;
  final SummaryDisplay display;
  final double confidence;
  final bool uncertainty;
}

class AnalysisWarning {
  const AnalysisWarning({
    required this.code,
    required this.detail,
    required this.sourcePages,
  });
  final String code, detail;
  final List<int> sourcePages;
}

class PageMode {
  const PageMode({required this.page, required this.mode});
  final int page;
  final PageModeKind mode;
}

class PartialExtraction {
  const PartialExtraction({
    required this.isPartial,
    required this.analyzedPages,
    required this.partialPages,
    required this.missingPages,
    required this.pageModes,
  });
  final bool isPartial;
  final List<int> analyzedPages, partialPages, missingPages;
  final List<PageMode> pageModes;
}

class StructuredSummary {
  const StructuredSummary({
    required this.schemaVersion,
    required this.language,
    required this.overviewMarkdown,
    required this.topicTitles,
    required this.sections,
    required this.keyConcepts,
    required this.equations,
    required this.warnings,
    required this.partialExtraction,
  });
  final int schemaVersion;
  final String language;
  final String overviewMarkdown;
  final List<String> topicTitles;
  final List<StructuredSection> sections;
  final List<KeyConcept> keyConcepts;
  final List<Equation> equations;
  final List<AnalysisWarning> warnings;
  final PartialExtraction partialExtraction;
  Equation? equationById(String id) {
    for (final e in equations) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class StructuredSummaryFormatException implements Exception {
  const StructuredSummaryFormatException();
}

class StructuredSummaryDecoder {
  const StructuredSummaryDecoder();
  StructuredSummary decode(
    Object? value, {
    required int schemaVersion,
    required int pageCount,
  }) {
    if (schemaVersion != 1 || pageCount < 1 || pageCount > 100) _bad();
    final raw = _asMap(value);
    final compact =
        raw.containsKey('overview_markdown') && raw.containsKey('topic_titles');
    final r = _map(value, {
      'language',
      if (compact) 'overview_markdown',
      if (compact) 'topic_titles',
      'sections',
      'key_concepts',
      'equations',
      'warnings',
      'partial_extraction',
    });
    final equations = _list(
      r['equations'],
      100,
    ).map((e) => _equation(e, pageCount)).toList(growable: false);
    final ids = equations.map((e) => e.id).toList();
    if (ids.toSet().length != ids.length) _bad();
    final refs = <String>[];
    final sections = _list(r['sections'], compact ? 6 : 24, min: 1)
        .map((v) {
          final m = _map(v, {
            'id',
            'title',
            'blocks',
            'source_pages',
            'confidence',
          });
          final blocks = _list(m['blocks'], 50, min: 1)
              .map((b) {
                final raw = _asMap(b);
                if (raw['kind'] == 'prose') {
                  final x = _map(b, {'kind', 'markdown', 'display'});
                  return ProseBlock(
                    markdown: _string(x['markdown'], 6000),
                    display: _display(x['display']),
                  );
                }
                if (raw['kind'] == 'equation') {
                  final x = _map(b, {'kind', 'equation_id', 'display'});
                  final id = _id(x['equation_id'], equation: true);
                  refs.add(id);
                  return EquationBlock(
                    equationId: id,
                    display: _display(x['display']),
                  );
                }
                _bad();
              })
              .toList(growable: false);
          return StructuredSection(
            id: _id(m['id']),
            title: _string(m['title'], 200),
            blocks: blocks,
            sourcePages: _pages(m['source_pages'], pageCount, min: 1),
            confidence: _confidence(m['confidence']),
          );
        })
        .toList(growable: false);
    if (refs.toSet().length != refs.length ||
        refs.any((id) => !ids.contains(id)) ||
        ids.any((id) => !refs.contains(id))) {
      _bad();
    }
    final concepts = _list(r['key_concepts'], compact ? 12 : 50)
        .map((v) {
          final m = _map(v, {
            'title',
            'explanation_markdown',
            'source_pages',
            'confidence',
          });
          return KeyConcept(
            title: _string(m['title'], 200),
            explanationMarkdown: _string(m['explanation_markdown'], 3000),
            sourcePages: _pages(m['source_pages'], pageCount, min: 1),
            confidence: _confidence(m['confidence']),
          );
        })
        .toList(growable: false);
    final warnings = _list(
      r['warnings'],
      100,
    ).map((v) => decodeWarning(v, pageCount)).toList(growable: false);
    final partial = _partial(r['partial_extraction'], pageCount);
    final authority = {...partial.analyzedPages, ...partial.partialPages};
    if (sections.any((s) => s.sourcePages.any((p) => !authority.contains(p))) ||
        concepts.any((c) => c.sourcePages.any((p) => !authority.contains(p))) ||
        equations.any((e) => !authority.contains(e.sourcePage))) {
      _bad();
    }
    final overview = compact
        ? _overview(r['overview_markdown'])
        : _legacyOverview(sections);
    final topics = compact
        ? _topics(r['topic_titles'])
        : _legacyTopics(sections, concepts);
    return StructuredSummary(
      schemaVersion: schemaVersion,
      language: _string(r['language'], 32),
      overviewMarkdown: overview,
      topicTitles: topics,
      sections: sections,
      keyConcepts: concepts,
      equations: equations,
      warnings: warnings,
      partialExtraction: partial,
    );
  }

  AnalysisWarning decodeWarning(Object? v, int count) {
    final m = _map(v, {'code', 'detail', 'source_pages'});
    final code = _string(m['code'], 64);
    if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(code)) _bad();
    return AnalysisWarning(
      code: code,
      detail: _string(m['detail'], 500),
      sourcePages: _pages(m['source_pages'], count),
    );
  }

  Equation _equation(Object? v, int c) {
    final m = _map(v, {
      'id',
      'latex',
      'explanation_markdown',
      'source_page',
      'display',
      'confidence',
      'uncertainty',
    });
    final latex = _string(m['latex'], 512);
    if (latex.trim().isEmpty) _bad();
    return Equation(
      id: _id(m['id'], equation: true),
      latex: latex,
      explanationMarkdown: _possiblyEmptyString(
        m['explanation_markdown'],
        2000,
      ),
      sourcePage: _page(m['source_page'], c),
      display: _display(m['display']),
      confidence: _confidence(m['confidence']),
      uncertainty: _bool(m['uncertainty']),
    );
  }

  PartialExtraction _partial(Object? v, int c) {
    final m = _map(v, {
      'is_partial',
      'analyzed_pages',
      'partial_pages',
      'missing_pages',
      'page_modes',
    });
    final a = _pages(m['analyzed_pages'], c),
        p = _pages(m['partial_pages'], c),
        x = _pages(m['missing_pages'], c);
    final all = [...a, ...p, ...x]..sort();
    if (all.length != c ||
        all.toSet().length != c ||
        !listEquals(all, [for (var i = 1; i <= c; i++) i])) {
      _bad();
    }
    final modes = _list(m['page_modes'], 100, min: 1)
        .map((v) {
          final q = _map(v, {'page', 'mode'});
          return PageMode(
            page: _page(q['page'], c),
            mode: switch (q['mode']) {
              'text' => PageModeKind.text,
              'visual' => PageModeKind.visual,
              _ => throw const StructuredSummaryFormatException(),
            },
          );
        })
        .toList(growable: false);
    final mp = modes.map((e) => e.page).toList()..sort();
    if (!listEquals(mp, [for (var i = 1; i <= c; i++) i]) ||
        modes.map((e) => e.page).toSet().length != modes.length) {
      _bad();
    }
    final flag = _bool(m['is_partial']);
    if (flag != (p.isNotEmpty || x.isNotEmpty)) _bad();
    return PartialExtraction(
      isPartial: flag,
      analyzedPages: a,
      partialPages: p,
      missingPages: x,
      pageModes: modes,
    );
  }
}

String _overview(Object? value) {
  final text = _string(value, 1200).trim();
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (paragraphs.length < 2 ||
      paragraphs.length > 4 ||
      RegExp(
        r'(^|\n)\s*(?:#{1,6}\s|[-*+]\s|>\s)',
        caseSensitive: false,
      ).hasMatch(text) ||
      RegExp(
        r'\b(?:page|pages|seite|seiten|страница|страницы|стр\.)\s*\d+',
        caseSensitive: false,
      ).hasMatch(text)) {
    _bad();
  }
  return text;
}

List<String> _topics(Object? value) {
  final topics = _list(
    value,
    8,
    min: 3,
  ).map((item) => _string(item, 80).trim()).toList(growable: false);
  if (topics.any((topic) => topic.isEmpty || topic.runes.length > 80) ||
      topics.map((topic) => topic.toLowerCase()).toSet().length !=
          topics.length) {
    _bad();
  }
  return List.unmodifiable(topics);
}

String _legacyOverview(List<StructuredSection> sections) {
  final paragraphs = <String>[];
  for (final section in sections) {
    for (final block in section.blocks) {
      if (block is! ProseBlock) continue;
      final prose = block.markdown.trim();
      if (prose.isNotEmpty) paragraphs.add(prose);
      if (paragraphs.length == 2) break;
    }
    if (paragraphs.length == 2) break;
  }
  return paragraphs.join('\n\n');
}

List<String> _legacyTopics(
  List<StructuredSection> sections,
  List<KeyConcept> concepts,
) {
  final result = <String>[], seen = <String>{};
  for (final candidate in [
    ...sections.map((section) => section.title),
    ...concepts.map((concept) => concept.title),
  ]) {
    final title = candidate.trim();
    if (title.isEmpty ||
        title.runes.length > 80 ||
        !seen.add(title.toLowerCase())) {
      continue;
    }
    result.add(title);
    if (result.length == 8) break;
  }
  return List.unmodifiable(result);
}

Never _bad() => throw const StructuredSummaryFormatException();
Map<String, Object?> _asMap(Object? v) {
  if (v is! Map) _bad();
  try {
    return Map<String, Object?>.from(v);
  } catch (_) {
    _bad();
  }
}

Map<String, Object?> _map(Object? v, Set<String> keys) {
  final m = _asMap(v);
  if (!setEquals(m.keys.toSet(), keys)) _bad();
  return m;
}

List<Object?> _list(Object? v, int max, {int min = 0}) {
  if (v is! List || v.length < min || v.length > max) _bad();
  return List.unmodifiable(v);
}

String _string(Object? v, int max) {
  if (v is! String || v.isEmpty || v.length > max || v.contains('\u0000')) {
    _bad();
  }
  return v;
}

String _possiblyEmptyString(Object? v, int max) {
  if (v is! String || v.length > max || v.contains('\u0000')) _bad();
  return v;
}

bool _bool(Object? v) {
  if (v is! bool) _bad();
  return v;
}

double _confidence(Object? v) {
  if (v is! num || !v.isFinite || v < 0 || v > 1) _bad();
  return v.toDouble();
}

int _page(Object? v, int c) {
  if (v is! int || v < 1 || v > c) _bad();
  return v;
}

List<int> _pages(Object? v, int c, {int min = 0}) {
  final r = _list(v, 100, min: min).map((e) => _page(e, c)).toList();
  final s = [...r]..sort();
  if (!listEquals(r, s) || r.toSet().length != r.length) _bad();
  return List.unmodifiable(r);
}

String _id(Object? v, {bool equation = false}) {
  final s = _string(v, 64),
      re = equation
          ? RegExp(r'^eq_[a-z0-9_-]{1,60}$')
          : RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
  if (!re.hasMatch(s)) _bad();
  return s;
}

SummaryDisplay _display(Object? v) => switch (v) {
  'inline' => SummaryDisplay.inline,
  'block' => SummaryDisplay.block,
  _ => throw const StructuredSummaryFormatException(),
};
