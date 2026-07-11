import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:ai_study_buddy/shared/widgets/responsive_app_scaffold.dart';
import 'package:ai_study_buddy/shared/widgets/study_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'phase-10a4',
  email: 'student@example.test',
  displayName: 'Student',
);
const _card = Flashcard(
  id: 'phase-10a4-card',
  subjectId: 'biology',
  front: 'Question front',
  back: 'Answer back',
  topic: 'Cells',
  difficulty: FlashcardDifficulty.medium,
  isFavorite: false,
);

void main() {
  testWidgets(
    'progress uses the responsive shell and removes fictional metrics',
    (tester) async {
      await _pump(tester, const Size(390, 844));
      await _route(tester, AppRoutes.progress);
      expect(find.byType(ResponsiveAppScaffold), findsOneWidget);
      expect(find.text('Knowledge scores'), findsNothing);
      expect(find.text('Study history'), findsNothing);
      expect(find.textContaining('Streak'), findsNothing);
      expect(find.textContaining('not a mastery score'), findsOneWidget);
    },
  );

  testWidgets('after lecture requires an explicit subject selection', (
    tester,
  ) async {
    await _pump(tester, const Size(800, 900));
    await _route(tester, AppRoutes.afterLecture);
    expect(find.text('Local prototype guidance'), findsOneWidget);
    expect(find.text('Select a subject'), findsOneWidget);
    expect(find.text('Create study session'), findsNothing);
  });

  testWidgets('AI Teacher is labeled as local mock prototype', (tester) async {
    await _pump(tester, const Size(1280, 900));
    await _route(
      tester,
      AppRoutes.aiTeacher,
      arguments: MockData.subjects.first,
    );
    expect(find.textContaining('Local mock coaching'), findsOneWidget);
    expect(find.textContaining('Prototype'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('training starts on front and reveals by activation', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));
    await _route(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: MockData.subjects.first,
        cards: const [_card],
      ),
    );
    expect(find.text('Question front'), findsOneWidget);
    expect(find.text('Answer back'), findsNothing);
    await tester.tap(find.byType(FlashcardSurface));
    await tester.pump();
    expect(find.text('Answer back'), findsOneWidget);
    expect(find.byKey(const ValueKey('rating-known')), findsOneWidget);
    expect(find.byKey(const ValueKey('rating-missed')), findsOneWidget);
  });

  testWidgets('study rows do not add row-level blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FocusTopicRow(topic: 'Cells', subject: 'Biology', missCount: 2),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('2 misses'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    StudyBuddyApp(authRepository: MockAuthRepository(initialUser: _user)),
  );
  await tester.pumpAndSettle();
}

Future<void> _route(
  WidgetTester tester,
  String name, {
  Object? arguments,
}) async {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed(name, arguments: arguments);
  await tester.pumpAndSettle();
}
