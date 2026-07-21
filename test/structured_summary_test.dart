import 'package:ai_study_buddy/features/materials/material_analysis_repository.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const decoder = StructuredSummaryDecoder();
  test('valid structured summary decodes immutable public model', () {
    final value = decoder.decode(_summary(), schemaVersion: 1, pageCount: 2);
    expect(value.sections.single.blocks.length, 2);
    expect(value.equationById('eq_one')?.sourcePage, 1);
    expect(value.partialExtraction.missingPages, [2]);
  });
  test('equation LaTeX must be non-blank and equations may be omitted', () {
    for (final latex in ['', ' \t\r\n']) {
      final invalid = _summary();
      ((invalid['equations'] as List).single as Map)['latex'] = latex;
      expect(
        () => decoder.decode(invalid, schemaVersion: 1, pageCount: 2),
        throwsA(isA<StructuredSummaryFormatException>()),
      );
    }
    final withoutEquations = _summary();
    withoutEquations['equations'] = <Object?>[];
    final blocks =
        ((withoutEquations['sections'] as List).single as Map)['blocks']
            as List;
    blocks.removeLast();
    final decoded = decoder.decode(
      withoutEquations,
      schemaVersion: 1,
      pageCount: 2,
    );
    expect(decoded.equations, isEmpty);
  });
  test('unsupported schema and unknown block are rejected', () {
    expect(
      () => decoder.decode(_summary(), schemaVersion: 2, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    final v = _summary();
    ((v['sections'] as List).single as Map<String, Object?>)['blocks'] = [
      {'kind': 'image', 'display': 'block'},
    ];
    expect(
      () => decoder.decode(v, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
  });
  test('equation reference page partition and confidence are strict', () {
    final badRef = _summary();
    ((((badRef['sections'] as List).single as Map)['blocks'] as List)[1]
            as Map)['equation_id'] =
        'eq_missing';
    expect(
      () => decoder.decode(badRef, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    final partition = _summary();
    ((partition['partial_extraction'] as Map)['missing_pages'] as List).clear();
    expect(
      () => decoder.decode(partition, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    final confidence = _summary();
    ((confidence['sections'] as List).single as Map)['confidence'] = 1.1;
    expect(
      () => decoder.decode(confidence, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
  });
  test('status safely rejects a malformed structured payload', () {
    final status = {
      'material_id': '22222222-2222-4222-8222-222222222222',
      'processing_mode': 'recommended',
      'state': 'completed',
      'public_stage': 'creating_summary',
      'page_count': 2,
      'completed_pages': 2,
      'confirmation_required': false,
      'can_retry': false,
      'retry_after_seconds': null,
      'warnings': <Object?>[],
      'summary_schema_version': 1,
      'summary_payload': {'bad': true},
    };
    expect(
      () => decodeMaterialAnalysisStatus(
        status,
        expectedMaterialId: status['material_id']! as String,
      ),
      throwsA(
        isA<MaterialAnalysisException>().having(
          (error) => error.code,
          'code',
          AnalysisErrorCode.invalidResponse,
        ),
      ),
    );
  });
  test('C2 string bounds accept max and reject max plus one', () {
    final cases = <(int, void Function(Map<String, Object?>, String))>[
      (
        6000,
        (value, text) =>
            ((((value['sections'] as List).single as Map)['blocks'] as List)
                        .first
                    as Map)['markdown'] =
                text,
      ),
      (
        200,
        (value, text) =>
            ((value['sections'] as List).single as Map)['title'] = text,
      ),
      (
        200,
        (value, text) =>
            ((value['key_concepts'] as List).single as Map)['title'] = text,
      ),
      (
        3000,
        (value, text) =>
            ((value['key_concepts'] as List).single
                    as Map)['explanation_markdown'] =
                text,
      ),
      (
        2000,
        (value, text) =>
            ((value['equations'] as List).single
                    as Map)['explanation_markdown'] =
                text,
      ),
      (32, (value, text) => value['language'] = text),
    ];
    for (final (maximum, change) in cases) {
      final valid = _summary();
      change(valid, 'x' * maximum);
      expect(
        () => decoder.decode(valid, schemaVersion: 1, pageCount: 2),
        returnsNormally,
      );
      final invalid = _summary();
      change(invalid, 'x' * (maximum + 1));
      expect(
        () => decoder.decode(invalid, schemaVersion: 1, pageCount: 2),
        throwsA(isA<StructuredSummaryFormatException>()),
      );
    }
    final emptyExplanation = _summary();
    ((emptyExplanation['equations'] as List).single
            as Map)['explanation_markdown'] =
        '';
    expect(
      () => decoder.decode(emptyExplanation, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
  });
  test('warning and source-page boundaries match C2', () {
    expect(
      () => decoder.decodeWarning({
        'code': 'warning',
        'detail': 'x' * 500,
        'source_pages': [1],
      }, 2),
      returnsNormally,
    );
    expect(
      () => decoder.decodeWarning({
        'code': 'warning',
        'detail': 'x' * 501,
        'source_pages': [1],
      }, 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    for (final key in ['sections', 'key_concepts']) {
      final value = _summary();
      ((value[key] as List).single as Map)['source_pages'] = <int>[];
      expect(
        () => decoder.decode(value, schemaVersion: 1, pageCount: 2),
        throwsA(isA<StructuredSummaryFormatException>()),
      );
    }
  });
  test('C2 collection bounds are exact', () {
    final sections = _summary();
    sections['equations'] = <Object?>[];
    sections['sections'] = [
      for (var index = 0; index < 24; index++)
        {
          'id': 'section_$index',
          'title': 'Title',
          'blocks': [
            {'kind': 'prose', 'markdown': 'Text', 'display': 'block'},
          ],
          'source_pages': [1],
          'confidence': 1,
        },
    ];
    expect(
      () => decoder.decode(sections, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    (sections['sections'] as List).add((sections['sections'] as List).first);
    expect(
      () => decoder.decode(sections, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );

    final blocks = _summary();
    blocks['equations'] = <Object?>[];
    ((blocks['sections'] as List).single as Map)['blocks'] = [
      for (var index = 0; index < 50; index++)
        {'kind': 'prose', 'markdown': 'Text $index', 'display': 'block'},
    ];
    expect(
      () => decoder.decode(blocks, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    (((blocks['sections'] as List).single as Map)['blocks'] as List).add({
      'kind': 'prose',
      'markdown': 'extra',
      'display': 'block',
    });
    expect(
      () => decoder.decode(blocks, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );

    final concepts = _summary();
    concepts['key_concepts'] = [
      for (var index = 0; index < 50; index++)
        {
          'title': 'Concept $index',
          'explanation_markdown': 'Explanation',
          'source_pages': [1],
          'confidence': 1,
        },
    ];
    expect(
      () => decoder.decode(concepts, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    (concepts['key_concepts'] as List).add(
      (concepts['key_concepts'] as List).first,
    );
    expect(
      () => decoder.decode(concepts, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
  });
  test('equation, warning, page-mode, ID, and confidence bounds are exact', () {
    final equations = _summary();
    final firstBlocks = <Object?>[];
    final secondBlocks = <Object?>[];
    final equationValues = <Object?>[];
    for (var index = 0; index < 100; index++) {
      final id = 'eq_$index';
      (index < 50 ? firstBlocks : secondBlocks).add({
        'kind': 'equation',
        'equation_id': id,
        'display': 'block',
      });
      equationValues.add({
        'id': id,
        'latex': 'x',
        'explanation_markdown': '',
        'source_page': 1,
        'display': 'block',
        'confidence': 1,
        'uncertainty': false,
      });
    }
    equations['sections'] = [
      {
        'id': 'first',
        'title': 'First',
        'blocks': firstBlocks,
        'source_pages': [1],
        'confidence': 1,
      },
      {
        'id': 'second',
        'title': 'Second',
        'blocks': secondBlocks,
        'source_pages': [1],
        'confidence': 1,
      },
    ];
    equations['equations'] = equationValues;
    expect(
      () => decoder.decode(equations, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    (equations['equations'] as List).add({
      'id': 'eq_100',
      'latex': 'x',
      'explanation_markdown': '',
      'source_page': 1,
      'display': 'block',
      'confidence': 1,
      'uncertainty': false,
    });
    ((equations['sections'] as List).last as Map)['blocks'].add({
      'kind': 'equation',
      'equation_id': 'eq_100',
      'display': 'block',
    });
    expect(
      () => decoder.decode(equations, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );

    final warnings = _summary();
    warnings['warnings'] = [
      for (var index = 0; index < 100; index++)
        {
          'code': 'warning_$index',
          'detail': 'Detail',
          'source_pages': [1],
        },
    ];
    expect(
      () => decoder.decode(warnings, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    (warnings['warnings'] as List).add((warnings['warnings'] as List).first);
    expect(
      () => decoder.decode(warnings, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );

    final limits = _summary();
    ((limits['sections'] as List).single as Map)['id'] = 's' * 64;
    ((limits['equations'] as List).single as Map)['latex'] = 'x' * 512;
    expect(
      () => decoder.decode(limits, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    ((limits['equations'] as List).single as Map)['latex'] = 'x' * 513;
    expect(
      () => decoder.decode(limits, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    final equationId = _summary();
    final maximumEquationId = 'eq_${'x' * 60}';
    ((equationId['equations'] as List).single as Map)['id'] = maximumEquationId;
    ((((equationId['sections'] as List).single as Map)['blocks'] as List)[1]
            as Map)['equation_id'] =
        maximumEquationId;
    expect(
      () => decoder.decode(equationId, schemaVersion: 1, pageCount: 2),
      returnsNormally,
    );
    ((equationId['equations'] as List).single as Map)['id'] = 'eq_${'x' * 61}';
    expect(
      () => decoder.decode(equationId, schemaVersion: 1, pageCount: 2),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    final modes = _summary();
    modes['partial_extraction'] = {
      'is_partial': false,
      'analyzed_pages': [for (var page = 1; page <= 100; page++) page],
      'partial_pages': <int>[],
      'missing_pages': <int>[],
      'page_modes': [
        for (var page = 1; page <= 100; page++) {'page': page, 'mode': 'text'},
      ],
    };
    expect(
      () => decoder.decode(modes, schemaVersion: 1, pageCount: 100),
      returnsNormally,
    );
    ((modes['partial_extraction'] as Map)['page_modes'] as List).add({
      'page': 1,
      'mode': 'text',
    });
    expect(
      () => decoder.decode(modes, schemaVersion: 1, pageCount: 100),
      throwsA(isA<StructuredSummaryFormatException>()),
    );
    for (final confidence in [0, 1]) {
      final value = _summary();
      ((value['sections'] as List).single as Map)['confidence'] = confidence;
      expect(
        () => decoder.decode(value, schemaVersion: 1, pageCount: 2),
        returnsNormally,
      );
    }
    for (final confidence in [-0.01, double.nan, double.infinity, 1.01]) {
      final value = _summary();
      ((value['sections'] as List).single as Map)['confidence'] = confidence;
      expect(
        () => decoder.decode(value, schemaVersion: 1, pageCount: 2),
        throwsA(isA<StructuredSummaryFormatException>()),
      );
    }
  });
}

Map<String, Object?> _summary() => {
  'language': 'en',
  'sections': [
    {
      'id': 'intro',
      'title': 'Intro',
      'blocks': [
        {'kind': 'prose', 'markdown': 'Safe **text**', 'display': 'block'},
        {'kind': 'equation', 'equation_id': 'eq_one', 'display': 'block'},
      ],
      'source_pages': [1],
      'confidence': 0.9,
    },
  ],
  'key_concepts': [
    {
      'title': 'Concept',
      'explanation_markdown': 'Explanation',
      'source_pages': [1],
      'confidence': 0.8,
    },
  ],
  'equations': [
    {
      'id': 'eq_one',
      'latex': r'\frac{a}{b}',
      'explanation_markdown': 'Fraction',
      'source_page': 1,
      'display': 'block',
      'confidence': 0.9,
      'uncertainty': false,
    },
  ],
  'warnings': <Object?>[],
  'partial_extraction': {
    'is_partial': true,
    'analyzed_pages': [1],
    'partial_pages': <int>[],
    'missing_pages': [2],
    'page_modes': [
      {'page': 1, 'mode': 'text'},
      {'page': 2, 'mode': 'visual'},
    ],
  },
};
