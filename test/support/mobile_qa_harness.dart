import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/theme.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setQaViewport(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget qaApp({
  required Widget home,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TargetPlatform platform = TargetPlatform.android,
}) {
  final lightTheme = buildAppTheme(
    Brightness.light,
  ).copyWith(platform: platform);
  final darkTheme = buildAppTheme(Brightness.dark).copyWith(platform: platform);
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: lightTheme,
    darkTheme: darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: padding,
        viewPadding: padding,
        viewInsets: viewInsets,
      ),
      child: child!,
    ),
    home: home,
  );
}

AppState qaAppState({MemoryAppPreferencesStore? preferencesStore}) => AppState(
  config: AppConfig.fromValues(),
  preferencesStore: preferencesStore ?? MemoryAppPreferencesStore(),
);

Future<void> boundedPump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void expectNoFrameworkException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
