import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login shell and enters dashboard', (tester) async {
    await tester.pumpWidget(const StudyBuddyApp());

    expect(find.text('AI Study Buddy'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do today?'), findsOneWidget);
    expect(find.text('After Lecture'), findsOneWidget);
    expect(find.text('Prepare for Exam'), findsOneWidget);
    expect(find.text('Continue Studying'), findsOneWidget);
  });

  testWidgets('adds pasted material to subject detail', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );
    await tester.tap(find.text('Add pasted text'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Material title'),
      'Cell respiration notes',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste lecture text'),
      'Cells release energy from glucose during respiration.',
    );
    await tester.tap(find.text('Save mock material'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Cell respiration notes'), findsOneWidget);
    expect(find.text('Just now - pasted text'), findsOneWidget);

    await tester.tap(find.text('Cell respiration notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    expect(
      find.text('Cells release energy from glucose during respiration.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Real AI generation from this material will be connected later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('favorite toggle updates favorites screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Where does photosynthesis happen?'), findsOneWidget);
  });

  testWidgets('favorites can unfavorite and remove a card', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('What is photosynthesis?'), findsOneWidget);

    final favoriteTile = find.ancestor(
      of: find.text('What is photosynthesis?'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: favoriteTile, matching: find.byTooltip('Unfavorite')),
    );
    await tester.pumpAndSettle();

    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('material detail can create a study session', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);
    expect(
      find.text(
        'Plants convert light, water, and carbon dioxide into glucose.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Real AI generation from this material will be connected later.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.text('Study Session'), findsOneWidget);
    expect(find.textContaining('Normal review'), findsOneWidget);
  });

  testWidgets('bottom navigation opens core routes', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.text('Subjects').last);
    await tester.pumpAndSettle();

    expect(find.text('Study Workspace'), findsOneWidget);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Knowledge scores'), findsOneWidget);
  });

  testWidgets('top quick actions open search and home', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do today?'), findsOneWidget);
  });

  testWidgets('scenario screens expose top quick actions only', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.afterLecture);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.text('Subjects'), findsNothing);

    await _pushRoute(tester, AppRoutes.examPrep);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.text('Progress'), findsNothing);
  });

  testWidgets('local search finds material and opens detail', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search study workspace'),
      'Photosynthesis',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photosynthesis lecture notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    expect(
      find.text(
        'Plants convert light, water, and carbon dioxide into glucose.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('after lecture creates local session and quiz result', (
    tester,
  ) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Simple explanation'), findsWidgets);
    expect(find.text('45 min'), findsOneWidget);

    await _scrollTo(tester, find.text('Oxygen'));
    await tester.tap(find.text('Oxygen'));
    await tester.pumpAndSettle();

    expect(find.text('Oxygen - incorrect'), findsOneWidget);
    expect(
      find.text(
        'Incorrect. Review the explanation, then retry the flashcards.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('You chose "Oxygen"'), findsOneWidget);
  });

  testWidgets('continue studying reads latest local session', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Oxygen'));
    await tester.tap(find.text('Oxygen'));
    await tester.pumpAndSettle();

    await _pushRoute(tester, AppRoutes.continueStudying);

    expect(find.text('Biology review'), findsOneWidget);
    expect(find.textContaining('Simple explanation'), findsOneWidget);
    expect(find.text('Biology quick quiz: 0%'), findsOneWidget);
  });
}

Future<void> _enterDashboard(WidgetTester tester) async {
  await tester.pumpWidget(const StudyBuddyApp());
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
}

Future<void> _pushRoute(
  WidgetTester tester,
  String routeName, {
  Object? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(routeName, arguments: arguments);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}
