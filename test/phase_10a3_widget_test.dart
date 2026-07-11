import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:ai_study_buddy/shared/widgets/glass_components.dart';
import 'package:ai_study_buddy/shared/widgets/responsive_app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'phase-10a3-user',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  testWidgets('usage is honest and contains no prototype quota data', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));
    await _route(tester, AppRoutes.usage);

    expect(find.byType(ResponsiveAppScaffold), findsOneWidget);
    expect(find.text('Usage tracking is not connected yet'), findsOneWidget);
    expect(find.textContaining('tokens='), findsNothing);
    expect(find.textContaining(r'$0.25'), findsNothing);
    expect(find.textContaining('/day'), findsNothing);
  });

  testWidgets('generated output is labeled as a static prototype preview', (
    tester,
  ) async {
    await _pump(tester, const Size(800, 900));
    await _route(
      tester,
      AppRoutes.generatedOutputs,
      arguments: MockData.subjects.first,
    );

    expect(find.text('Prototype preview'), findsWidgets);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Open flashcards'), findsOneWidget);
  });

  testWidgets('search has guidance and an accessible clear action', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));
    await _route(tester, AppRoutes.search);

    expect(find.text('Start typing to search'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'photo');
    await tester.pump();
    expect(find.byKey(const ValueKey('clear-search-query')), findsOneWidget);
    expect(find.text('Materials (1)'), findsOneWidget);
  });

  testWidgets('favorites groups rows without row-level glass', (tester) async {
    await _pump(tester, const Size(390, 844));
    await _route(tester, AppRoutes.favorites);

    expect(
      find.byKey(const ValueKey('favorites-flashcards-group')),
      findsOneWidget,
    );
    final rows = find.descendant(
      of: find.byKey(const ValueKey('favorites-flashcards-group')),
      matching: find.byType(AppListRow),
    );
    expect(rows, findsWidgets);
    expect(
      find.descendant(of: rows.first, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
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
