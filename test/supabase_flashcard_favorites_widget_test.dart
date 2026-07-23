import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/flashcard.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/persisted_study_activity.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/favorites/favorite_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_repository.dart';
import 'package:ai_study_buddy/features/flashcards/flashcard_training_screen.dart';
import 'package:ai_study_buddy/features/flashcards/flashcards_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/study_sessions/study_activity_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Supabase review exposes favorite and restores it after reload', (
    tester,
  ) async {
    final favorites = _FavoriteRepository();
    await _pump(tester, favorites: favorites);
    await _route(tester, AppRoutes.flashcards, arguments: _materialOneArgs);

    expect(find.byTooltip('Favorite'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.byTooltip('Favorite').first,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pumpAndSettle();

    expect(favorites.added, hasLength(1));
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    final context = tester.element(find.byType(FlashcardsScreen));
    await AppStateScope.read(context).loadMaterialFavoritesFor(_user);
    await AppStateScope.read(context).loadFlashcardsFor(_user);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('Supabase review unfavorite invokes repository', (tester) async {
    final favorites = _FavoriteRepository(initial: {'card-1'});
    await _pump(tester, favorites: favorites);
    await _route(tester, AppRoutes.flashcards, arguments: _materialOneArgs);

    await tester.scrollUntilVisible(
      find.byTooltip('Remove from favorites'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();

    expect(favorites.removed, ['card-1']);
    expect(find.byTooltip('Favorite'), findsNWidgets(2));
  });

  testWidgets('favorite failure is visible and leaves state unchanged', (
    tester,
  ) async {
    final favorites = _FavoriteRepository(failAdd: true);
    await _pump(tester, favorites: favorites);
    await _route(tester, AppRoutes.flashcards, arguments: _materialOneArgs);

    await tester.scrollUntilVisible(
      find.byTooltip('Favorite').first,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pump();

    expect(find.text('Could not update favorite.'), findsOneWidget);
    expect(find.byTooltip('Remove from favorites'), findsNothing);
  });

  testWidgets('material-scoped training exposes authoritative favorite', (
    tester,
  ) async {
    final favorites = _FavoriteRepository();
    await _pump(tester, favorites: favorites);
    await _route(
      tester,
      AppRoutes.flashcardTraining,
      arguments: FlashcardTrainingArgs(
        subject: _subject,
        material: _materialOne,
        cards: const [_cardOne],
        session: _session(cardIds: const ['card-1']),
      ),
    );

    expect(find.byTooltip('Favorite'), findsOneWidget);
    await tester.tap(find.byTooltip('Favorite'));
    await tester.pumpAndSettle();
    expect(favorites.added, ['card-1']);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('favorite-only review never leaks another material', (
    tester,
  ) async {
    final favorites = _FavoriteRepository(initial: {'card-1', 'card-3'});
    final sessions = _StudyRepository();
    await _pump(tester, favorites: favorites, sessions: sessions);
    await _route(tester, AppRoutes.favorites);

    await tester.tap(find.text('Card one'));
    await tester.pumpAndSettle();

    expect(sessions.startedCardIds, ['card-1']);
    expect(sessions.startedMode, FlashcardTrainingMode.favorites);
    expect(find.text('Card one'), findsOneWidget);
    expect(find.text('Other material card'), findsNothing);
  });

  testWidgets('empty active session can be cancelled without history', (
    tester,
  ) async {
    final sessions = _StudyRepository(
      active: _session(cardIds: const ['card-1']),
    );
    await _pump(tester, favorites: _FavoriteRepository(), sessions: sessions);
    await _route(tester, AppRoutes.continueStudying);

    expect(find.text('Cancel empty session'), findsOneWidget);
    await tester.tap(find.text('Cancel empty session'));
    await tester.pumpAndSettle();

    expect(sessions.cancelled, ['session-1']);
    expect(sessions.completed, isEmpty);
    expect(find.text('Nothing to continue'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FavoriteRepository favorites,
  _StudyRepository? sessions,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      config: _config,
      authRepository: MockAuthRepository(initialUser: _user),
      subjectRepository: MockSubjectRepository(
        initialSubjects: const [_subject],
      ),
      materialRepository: MockMaterialRepository(
        initialMaterials: const [_materialOne, _materialTwo],
      ),
      flashcardRepository: _FlashcardRepository(),
      favoriteRepository: favorites,
      studyActivityRepository: sessions ?? _StudyRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _route(
  WidgetTester tester,
  String route, {
  Object? arguments,
}) async {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed(route, arguments: arguments);
  await tester.pumpAndSettle();
}

const _config = AppConfig(
  backendMode: AppBackendMode.supabase,
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'sb_publishable_test-client-key',
);
const _user = AuthUser(id: 'user-1', email: 'learner@example.test');
const _subject = Subject(
  id: 'subject-1',
  name: 'Physics',
  description: 'Physics',
  colorValue: 0xFF3366CC,
);
const _materialOne = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Spring energy',
  kind: MaterialKind.pastedText,
  content: 'Elastic potential energy depends on displacement and stiffness.',
  createdLabel: 'Today',
);
const _materialTwo = StudyMaterial(
  id: 'material-2',
  subjectId: 'subject-1',
  title: 'Waves',
  kind: MaterialKind.pastedText,
  content: 'Wave speed depends on frequency and wavelength.',
  createdLabel: 'Today',
);
const _cardOne = Flashcard(
  id: 'card-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'Card one',
  back: 'Answer one',
  topic: 'Springs',
  isFavorite: false,
);
const _cardTwo = Flashcard(
  id: 'card-2',
  subjectId: 'subject-1',
  materialId: 'material-1',
  front: 'Card two',
  back: 'Answer two',
  topic: 'Springs',
  isFavorite: false,
);
const _cardOther = Flashcard(
  id: 'card-3',
  subjectId: 'subject-1',
  materialId: 'material-2',
  front: 'Other material card',
  back: 'Other answer',
  topic: 'Waves',
  isFavorite: false,
);
const _materialOneArgs = FlashcardsRouteArgs(
  subject: _subject,
  materialId: 'material-1',
  materialTitle: 'Spring energy',
);

PersistedStudyActivity _session({required List<String> cardIds}) =>
    PersistedStudyActivity(
      id: 'session-1',
      subjectId: 'subject-1',
      materialId: 'material-1',
      type: PersistedStudyActivityType.flashcards,
      version: 1,
      currentIndex: 0,
      itemIds: cardIds,
      updatedAt: DateTime.utc(2026, 7, 23),
      flashcardMode: FlashcardTrainingMode.all,
    );

class _FlashcardRepository implements FlashcardRepository {
  @override
  Future<List<Flashcard>> loadFlashcards(AuthUser user) async => const [
    _cardOne,
    _cardTwo,
    _cardOther,
  ];

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
  }) async => card;
}

class _FavoriteRepository
    implements FavoriteRepository, FlashcardFavoriteRepository {
  _FavoriteRepository({Set<String> initial = const {}, this.failAdd = false})
    : ids = {...initial};
  final Set<String> ids;
  final bool failAdd;
  final List<String> added = [];
  final List<String> removed = [];

  @override
  Future<Set<String>> loadMaterialFavoriteIds(AuthUser user) async => const {};
  @override
  Future<Set<String>> loadFlashcardFavoriteIds(AuthUser user) async => {...ids};
  @override
  Future<void> addFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    added.add(flashcardId);
    if (failAdd) {
      throw const FavoriteRepositoryException('Could not update favorite.');
    }
    ids.add(flashcardId);
  }

  @override
  Future<void> removeFlashcardFavorite({
    required AuthUser user,
    required String flashcardId,
  }) async {
    removed.add(flashcardId);
    ids.remove(flashcardId);
  }

  @override
  Future<void> addMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {}
  @override
  Future<void> removeMaterialFavorite({
    required AuthUser user,
    required String materialId,
  }) async {}
}

class _StudyRepository extends EmptyStudyActivityRepository {
  _StudyRepository({this.active});
  PersistedStudyActivity? active;
  final List<String> completed = [];
  final List<String> cancelled = [];
  List<String> startedCardIds = [];
  FlashcardTrainingMode? startedMode;

  @override
  Future<List<PersistedStudyActivity>> loadActive(AuthUser user) async => [
    ?active,
  ];
  @override
  Future<List<PersistedStudyActivity>> loadRecentCompleted(
    AuthUser user,
  ) async => const [];
  @override
  Future<PersistedStudyActivity> startFlashcards({
    required AuthUser user,
    required String sessionId,
    required String materialId,
    required FlashcardTrainingMode mode,
    required List<String> cardIds,
  }) async {
    startedCardIds = [...cardIds];
    startedMode = mode;
    return PersistedStudyActivity(
      id: sessionId,
      subjectId: 'subject-1',
      materialId: materialId,
      type: PersistedStudyActivityType.flashcards,
      version: 1,
      currentIndex: 0,
      itemIds: cardIds,
      updatedAt: DateTime.utc(2026, 7, 23),
      flashcardMode: mode,
    );
  }

  @override
  Future<void> cancelEmptySession({
    required AuthUser user,
    required String sessionId,
  }) async {
    cancelled.add(sessionId);
    active = null;
  }
}
