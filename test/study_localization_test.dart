import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:ai_study_buddy/shared/widgets/study_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('study plurals cover 0, 1, 2, and 5 in every locale', () {
    for (final locale in const [Locale('en'), Locale('de'), Locale('ru')]) {
      final l10n = lookupAppLocalizations(locale);
      for (final count in const [0, 1, 2, 5]) {
        expect(l10n.studyCards(count), isNotEmpty);
        expect(l10n.studyQuestions(count), isNotEmpty);
        expect(l10n.studyAttempts(count), isNotEmpty);
        expect(l10n.studyMisses(count), isNotEmpty);
        expect(l10n.trainingReviewed(count), isNotEmpty);
        expect(l10n.trainingKnown(count), isNotEmpty);
        expect(l10n.trainingMissed(count), isNotEmpty);
      }
    }
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.studyAttempts(1), '1 попытка');
    expect(ru.studyAttempts(2), '2 попытки');
    expect(ru.studyAttempts(5), '5 попыток');
    expect(ru.studyMisses(1), '1 ошибка');
    expect(ru.studyMisses(2), '2 ошибки');
    expect(ru.studyMisses(5), '5 ошибок');
  });

  for (final locale in const [Locale('en'), Locale('de'), Locale('ru')]) {
    testWidgets('flashcard chrome localizes and source content stays unchanged in ${locale.languageCode}', (tester) async {
      const front = 'SOURCE FRONT Ω';
      const back = 'SOURCE BACK Ж';
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: FlashcardSurface(
            front: front,
            back: back,
            isAnswerVisible: false,
            onToggleAnswer: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(front), findsOneWidget);
      expect(find.text(back), findsNothing);
      expect(find.text(lookupAppLocalizations(locale).studyQuestion), findsOneWidget);
    });
  }
}
