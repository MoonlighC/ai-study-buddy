import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:ai_study_buddy/l10n/localized_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final material = StudyMaterial(
    id: 'material',
    subjectId: 'subject',
    title: 'Source title',
    kind: MaterialKind.pastedText,
    content: 'Source content',
    createdLabel: 'Today',
  );

  test('legacy material labels are bounded and localized', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(LocalizedFormatters.materialDate(de, material), 'Heute');
    expect(LocalizedFormatters.materialDate(ru, material), 'Сегодня');
    expect(
      LocalizedFormatters.materialDate(
        de,
        StudyMaterial(
          id: 'x',
          subjectId: 's',
          title: 't',
          kind: MaterialKind.pastedText,
          content: '',
          createdLabel: 'Arbitrary English backend text',
        ),
      ),
      'Kürzlich',
    );
  });

  test('relative and absolute dates use the selected locale', () {
    final now = DateTime(2026, 7, 11, 12);
    for (final locale in const [Locale('en'), Locale('de'), Locale('ru')]) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        LocalizedFormatters.dateOrRelative(
          l10n,
          DateTime(2026, 7, 11, 11, 58),
          now: now,
        ),
        l10n.relativeJustNow,
      );
      expect(
        LocalizedFormatters.dateOrRelative(
          l10n,
          DateTime(2026, 7, 10, 10),
          now: now,
        ),
        l10n.relativeYesterday,
      );
      expect(
        LocalizedFormatters.dateOrRelative(
          l10n,
          DateTime(2026, 7, 1),
          now: now,
        ),
        isNot(contains('2026-07-01')),
      );
    }
  });

  test('numbers, percentages, and IEC sizes honor locale punctuation', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(LocalizedFormatters.percentage(en, 33.33), contains('33.33'));
    expect(LocalizedFormatters.percentage(de, 33.33), contains('33,33'));
    expect(LocalizedFormatters.percentage(ru, 33.33), contains('33,33'));
    expect(LocalizedFormatters.fileSize(en, 1024), '1 KiB');
    expect(LocalizedFormatters.fileSize(de, 1536), '1,5 KiB');
    expect(LocalizedFormatters.fileSize(ru, 1536), '1,5 КиБ');
    expect(LocalizedFormatters.fileSize(en, 1024 * 1024), '1 MiB');
  });

  test('count messages cover 0, 1, 2, 5, and 21 in every locale', () {
    for (final locale in const [Locale('en'), Locale('de'), Locale('ru')]) {
      final l10n = lookupAppLocalizations(locale);
      for (final count in const [0, 1, 2, 5, 21]) {
        expect(l10n.studyCards(count), isNotEmpty);
        expect(l10n.studyQuestions(count), isNotEmpty);
        expect(l10n.studyAttempts(count), isNotEmpty);
        expect(l10n.studyMisses(count), isNotEmpty);
        expect(l10n.materialsCount(count), isNotEmpty);
        expect(l10n.materialPagesCount(count), isNotEmpty);
        expect(l10n.flashcardsNewGenerated(count), isNotEmpty);
      }
    }
  });
}
