import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/usage/usage_status_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'usage-user',
  email: 'usage@example.test',
  displayName: 'Usage Tester',
);

void main() {
  testWidgets('standard policy renders authoritative limits and reset time', (
    tester,
  ) async {
    await _pump(
      tester,
      _FixedUsageRepository(
        UsageStatus(
          accountPolicy: UsageAccountPolicy.standard,
          flashcardsUsedToday: 12,
          flashcardsDailyLimit: 120,
          quizQuestionsUsedToday: 7,
          quizQuestionsDailyLimit: 80,
          estimatedCostUsedToday: 0.04,
          estimatedCostDailyLimit: 0.25,
          activeReservations: 1,
          resetAt: DateTime(2026, 7, 24, 0),
        ),
      ),
    );

    expect(find.text('Standard daily limits'), findsOneWidget);
    expect(find.text('12 / 120'), findsOneWidget);
    expect(find.text('7 / 80'), findsOneWidget);
    expect(find.text('0.04 / 0.25 USD'), findsOneWidget);
    expect(find.text('Active generations: 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-reset-at')), findsOneWidget);
  });

  testWidgets('unlimited tester renders actual usage without fake infinity', (
    tester,
  ) async {
    await _pump(
      tester,
      _FixedUsageRepository(
        UsageStatus(
          accountPolicy: UsageAccountPolicy.unlimitedTester,
          flashcardsUsedToday: 140,
          flashcardsDailyLimit: null,
          quizQuestionsUsedToday: 95,
          quizQuestionsDailyLimit: null,
          estimatedCostUsedToday: 0.42,
          estimatedCostDailyLimit: null,
          activeReservations: 0,
          resetAt: DateTime(2026, 7, 24, 0),
        ),
      ),
    );

    expect(
      find.text('Tester mode: unlimited daily generation'),
      findsOneWidget,
    );
    expect(find.text('140 today'), findsOneWidget);
    expect(find.text('95 today'), findsOneWidget);
    expect(find.text('0.42 USD today'), findsOneWidget);
    expect(find.textContaining('∞'), findsNothing);
    expect(find.textContaining('duplicate/retry protections'), findsOneWidget);
  });

  testWidgets('usage retrieval failure is visible and retry is real', (
    tester,
  ) async {
    final repository = _FailingThenFixedUsageRepository();
    await _pump(tester, repository, settle: false);
    await tester.pumpAndSettle();

    expect(find.text('Could not load usage'), findsOneWidget);
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Standard daily limits'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('dashboard usage icon opens the real Usage screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        authRepository: MockAuthRepository(initialUser: _user),
        usageStatusRepository: _FixedUsageRepository(_standard),
      ),
    );
    await tester.pumpAndSettle();
    await _push(tester, AppRoutes.dashboard);

    await tester.tap(find.byKey(const ValueKey('top-usage-action')));
    await tester.pumpAndSettle();
    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Standard daily limits'), findsOneWidget);
  });
}

final _standard = UsageStatus(
  accountPolicy: UsageAccountPolicy.standard,
  flashcardsUsedToday: 0,
  flashcardsDailyLimit: 120,
  quizQuestionsUsedToday: 0,
  quizQuestionsDailyLimit: 80,
  estimatedCostUsedToday: 0,
  estimatedCostDailyLimit: 0.25,
  activeReservations: 0,
  resetAt: DateTime.utc(2026, 7, 24),
);

Future<void> _pump(
  WidgetTester tester,
  UsageStatusRepository repository, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      authRepository: MockAuthRepository(initialUser: _user),
      usageStatusRepository: repository,
    ),
  );
  await tester.pumpAndSettle();
  await _push(tester, AppRoutes.usage, settle: settle);
}

Future<void> _push(
  WidgetTester tester,
  String route, {
  bool settle = true,
}) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  if (settle) await tester.pumpAndSettle();
}

class _FixedUsageRepository implements UsageStatusRepository {
  _FixedUsageRepository(this.status);

  final UsageStatus status;

  @override
  Future<UsageStatus> loadUsageStatus(AuthUser user) async => status;
}

class _FailingThenFixedUsageRepository implements UsageStatusRepository {
  int calls = 0;

  @override
  Future<UsageStatus> loadUsageStatus(AuthUser user) async {
    calls++;
    if (calls == 1) throw const UsageStatusRepositoryException();
    return _standard;
  }
}
