import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:ai_study_buddy/l10n/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> map(
    WidgetTester tester,
    Locale locale,
    String message,
  ) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = context.localizedSafeMessage(message);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('known, parameterized, and unknown errors are bounded', (
    tester,
  ) async {
    expect(
      await map(tester, const Locale('de'), 'Enter a valid email address.'),
      lookupAppLocalizations(const Locale('de')).errorEnterValidEmail,
    );
    expect(
      await map(
        tester,
        const Locale('ru'),
        'If an account exists for learner@example.test, a reset email is on the way.',
      ),
      contains('learner@example.test'),
    );
    expect(
      await map(
        tester,
        const Locale('de'),
        'The selected file exceeds 10 MiB.',
      ),
      contains('10 MiB'),
    );
    final unknown = await map(
      tester,
      const Locale('ru'),
      'Sensitive backend details must not escape',
    );
    expect(
      unknown,
      lookupAppLocalizations(const Locale('ru')).genericLocalizedError,
    );
    expect(unknown, isNot(contains('backend')));
  });
}
