import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/knowledge_score.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcards_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/material_detail_screen.dart';
import 'package:ai_study_buddy/features/progress/progress_screen.dart';
import 'package:ai_study_buddy/features/progress/study_progress_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress model rejects unversioned responses', () {
    expect(
      () => StudyProgress.fromJson(const {'schema_version': 2}),
      throwsFormatException,
    );
  });

  testWidgets('zero evidence displays Not enough activity', (tester) async {
    await _pump(tester, _progress(metrics: _metrics()));
    await _openProgress(tester);
    expect(find.text('Not enough activity'), findsWidgets);
    expect(
      find.text('Quiz evidence: 0 answers · Flashcard evidence: 0 cards'),
      findsOneWidget,
    );
  });

  testWidgets('quiz-only score and evidence are authoritative', (tester) async {
    await _pump(
      tester,
      _progress(
        metrics: _metrics(
          knowledgeScore: 66.67,
          quizAccuracy: 60,
          quizCorrect: 3,
          quizTotal: 5,
          quizAttempts: 1,
        ),
      ),
    );
    await _openProgress(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('knowledge-score'))).data,
      '66.67%',
    );
    expect(
      find.text('Quiz evidence: 5 answers · Flashcard evidence: 0 cards'),
      findsOneWidget,
    );
  });

  testWidgets('flashcard-only score and evidence are authoritative', (
    tester,
  ) async {
    await _pump(
      tester,
      _progress(metrics: _metrics(knowledgeScore: 60, known: 4, notKnown: 2)),
    );
    await _openProgress(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('knowledge-score'))).data,
      '60.00%',
    );
    expect(
      find.text('Quiz evidence: 0 answers · Flashcard evidence: 6 cards'),
      findsOneWidget,
    );
  });

  testWidgets('combined score, recent session, and no mock constants render', (
    tester,
  ) async {
    await _pump(tester, _progress());
    await _openProgress(tester);
    expect(find.text('52.86%'), findsWidgets);
    expect(find.text('Mechanics'), findsWidgets);
    expect(find.text('Momentum'), findsOneWidget);
    expect(find.text('Biology'), findsNothing);
    expect(find.text('Math'), findsNothing);
    expect(find.text('German'), findsNothing);
  });

  testWidgets('subject and material cards open scoped progress', (
    tester,
  ) async {
    await _pump(tester, _progress());
    await _openProgress(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('progress-group-subject-1')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('progress-group-subject-1')));
    await tester.pumpAndSettle();
    expect(find.text('Physics'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('progress-group-material-1')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('progress-group-material-1')));
    await tester.pumpAndSettle();
    expect(find.text('Mechanics'), findsWidgets);
    expect(find.byKey(const ValueKey('progress-due-cards')), findsOneWidget);
  });

  testWidgets('weak topic opens its real material', (tester) async {
    await _pump(tester, _progress());
    await _openProgress(tester);
    await tester.ensureVisible(find.text('Momentum'));
    await tester.tap(find.text('Momentum'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDetailScreen), findsOneWidget);
  });

  testWidgets('due-card navigation keeps material scope', (tester) async {
    await _pump(tester, _progress());
    await _openProgress(
      tester,
      const ProgressRouteArgs(subjectId: 'subject-1', materialId: 'material-1'),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('progress-due-cards')),
    );
    expect(
      tester.widget<ProgressScreen>(find.byType(ProgressScreen)).args.materialId,
      'material-1',
    );
    expect(
      AppStateScope.read(tester.element(find.byType(ProgressScreen)))
          .materialById('material-1'),
      isNotNull,
    );
    final action = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('progress-due-cards')),
    );
    expect(action.onTap, isNotNull);
    action.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(FlashcardsScreen), findsOneWidget);
    expect(find.textContaining('Mechanics'), findsWidgets);
    expect(find.text('A Mechanics question'), findsOneWidget);
  });

  testWidgets('dashboard uses RPC knowledge score and real recent session', (
    tester,
  ) async {
    await _pump(tester, _progress());
    expect(find.text('52.86%'), findsOneWidget);
    expect(find.text('Mechanics'), findsWidgets);
    expect(find.text('Biology'), findsNothing);
    await tester.ensureVisible(find.text('Open progress'));
    await tester.tap(find.text('Open progress'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('authoritative-progress')),
      findsOneWidget,
    );
  });
}

const _user = AuthUser(
  id: 'user-1',
  email: 'progress@example.test',
  displayName: 'Progress User',
);
const _subject = Subject(
  id: 'subject-1',
  name: 'Physics',
  description: '',
  colorValue: 0xff456789,
);
final _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Mechanics',
  kind: MaterialKind.pastedText,
  content: 'Authoritative mechanics material with enough content for study.',
  createdLabel: 'Today',
  createdAt: DateTime.utc(2026, 7, 22),
);
final _card = Flashcard(
  id: 'card-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'A Mechanics question',
  back: 'A material-specific answer',
  topic: 'Momentum',
  difficulty: FlashcardDifficulty.medium,
  isFavorite: false,
  correctCount: 0,
  incorrectCount: 1,
  nextReviewAt: DateTime.utc(2026, 7, 21),
);

Future<void> _pump(WidgetTester tester, StudyProgress progress) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      config: const AppConfig(
        environment: AppEnvironment.staging,
        backendMode: AppBackendMode.supabase,
        supabaseUrl: 'https://staging.supabase.co',
        supabaseAnonKey: 'sb_publishable_progress_test',
      ),
      authRepository: MockAuthRepository(initialUser: _user),
      profileRepository: NoopProfileRepository(),
      subjectRepository: MockSubjectRepository(initialSubjects: [_subject]),
      materialRepository: MockMaterialRepository(initialMaterials: [_material]),
      flashcardRepository: _StaticFlashcardRepository([_card]),
      studyProgressRepository: _StaticProgressRepository(progress),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openProgress(
  WidgetTester tester, [
  ProgressRouteArgs args = const ProgressRouteArgs(),
]) async {
  final context = tester.element(find.byType(Navigator).first);
  Navigator.of(context).pushNamed(AppRoutes.progress, arguments: args);
  await tester.pumpAndSettle();
}

StudyProgress _progress({ProgressMetrics? metrics}) {
  final current =
      metrics ??
      _metrics(
        knowledgeScore: 52.86,
        quizAccuracy: 50,
        quizCorrect: 5,
        quizTotal: 10,
        quizAttempts: 2,
        known: 2,
        notKnown: 1,
        weak: 1,
        due: 1,
        active: 1,
        completed: 1,
        sessions: [_session],
        topics: [_topic],
      );
  return StudyProgress(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 7, 22),
    global: current,
    subjects: [
      SubjectProgress(
        subjectId: 'subject-1',
        subjectName: 'Physics',
        metrics: current,
      ),
    ],
    materials: [
      MaterialProgress(
        materialId: 'material-1',
        materialTitle: 'Mechanics',
        subjectId: 'subject-1',
        subjectName: 'Physics',
        metrics: current,
      ),
    ],
    historical: const HistoricalProgress(
      label: 'Deleted or detached material activity',
      quizCorrectAnswers: 0,
      quizTotalAnswers: 0,
      completedQuizAttemptCount: 0,
      completedSessionCount: 0,
      recentCompletedSessions: [],
    ),
  );
}

ProgressMetrics _metrics({
  double? knowledgeScore,
  double? quizAccuracy,
  int quizCorrect = 0,
  int quizTotal = 0,
  int quizAttempts = 0,
  int known = 0,
  int notKnown = 0,
  int weak = 0,
  int due = 0,
  int active = 0,
  int completed = 0,
  List<ProgressSession> sessions = const [],
  List<ProgressWeakTopic> topics = const [],
}) => ProgressMetrics(
  quizCorrectAnswers: quizCorrect,
  quizTotalAnswers: quizTotal,
  quizAccuracy: quizAccuracy,
  completedQuizAttemptCount: quizAttempts,
  flashcardKnownCount: known,
  flashcardNotKnownCount: notKnown,
  weakCardCount: weak,
  dueCardCount: due,
  activeSessionCount: active,
  completedSessionCount: completed,
  quizEvidenceCount: quizTotal,
  flashcardEvidenceCount: known + notKnown,
  activeSessions: sessions,
  recentCompletedSessions: sessions,
  weakTopics: topics,
  knowledgeScore: knowledgeScore,
);

final _session = ProgressSession(
  sessionId: 'session-1',
  sessionType: 'flashcards',
  subjectId: 'subject-1',
  subjectName: 'Physics',
  materialId: 'material-1',
  materialTitle: 'Mechanics',
  currentProgress: 1,
  totalItems: 1,
  completedAt: DateTime.utc(2026, 7, 22),
);
final _topic = ProgressWeakTopic(
  id: 'topic-1',
  topic: 'Momentum',
  missCount: 2,
  subjectId: 'subject-1',
  subjectName: 'Physics',
  materialId: 'material-1',
  materialTitle: 'Mechanics',
  lastSeenAt: DateTime.utc(2026, 7, 22),
);

class _StaticProgressRepository implements StudyProgressRepository {
  const _StaticProgressRepository(this.progress);
  final StudyProgress progress;
  @override
  Future<StudyProgress> loadProgress(
    AuthUser user, {
    String? subjectId,
    String? materialId,
  }) async => progress;
}

class _StaticFlashcardRepository implements FlashcardRepository {
  const _StaticFlashcardRepository(this.cards);
  final List<Flashcard> cards;
  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async => cards;
  @override
  Future<FlashcardGenerationResult> generateFlashcards({
    required AuthUser user,
    required String materialId,
    required int requestedNewCount,
  }) => throw UnimplementedError();
  @override
  Future<Flashcard> updateReviewResult({
    required AuthUser user,
    required Flashcard card,
    required FlashcardReviewResult result,
    required DateTime reviewedAt,
  }) => throw UnimplementedError();
}
