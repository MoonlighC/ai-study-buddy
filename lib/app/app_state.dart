import 'package:flutter/material.dart';

import 'app_config.dart';
import '../core/models/flashcard.dart';
import '../core/models/material.dart';
import '../core/models/quiz.dart';
import '../core/models/quiz_attempt.dart';
import '../core/models/quiz_question.dart';
import '../core/models/study_session.dart';
import '../core/models/study_time_block.dart';
import '../core/models/subject.dart';
import '../core/models/weak_topic.dart';
import '../features/auth/auth_models.dart';
import '../features/favorites/favorite_repository.dart';
import '../features/flashcards/flashcard_repository.dart';
import '../features/generation/summary_repository.dart';
import '../features/materials/material_repository.dart';
import '../features/quizzes/quiz_repository.dart';
import '../features/subjects/subject_repository.dart';
import '../mock/mock_ai_service.dart';
import '../mock/mock_data.dart';

class AppState extends ChangeNotifier {
  AppState({
    AppConfig? config,
    SubjectRepository? subjectRepository,
    MaterialRepository? materialRepository,
    FavoriteRepository? favoriteRepository,
    FlashcardRepository? flashcardRepository,
    SummaryRepository? summaryRepository,
    QuizRepository? quizRepository,
  }) : config = config ?? AppConfig.fromValues(),
       subjectRepository =
           subjectRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptySubjectRepository()
               : MockSubjectRepository()),
       materialRepository =
           materialRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyMaterialRepository()
               : MockMaterialRepository()),
       favoriteRepository =
           favoriteRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyFavoriteRepository()
               : MockFavoriteRepository()),
       flashcardRepository =
           flashcardRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyFlashcardRepository()
               : const MockFlashcardRepository()),
       summaryRepository =
           summaryRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptySummaryRepository()
               : const MockSummaryRepository()),
       quizRepository =
           quizRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyQuizRepository()
               : MockQuizRepository()),
       _subjects =
           (config ?? AppConfig.fromValues()).effectiveBackendMode ==
               AppBackendMode.supabase
           ? <Subject>[]
           : List<Subject>.of(MockData.subjects),
       _materials =
           (config ?? AppConfig.fromValues()).effectiveBackendMode ==
               AppBackendMode.supabase
           ? <StudyMaterial>[]
           : List<StudyMaterial>.of(MockData.materials),
       _flashcards =
           (config ?? AppConfig.fromValues()).effectiveBackendMode ==
               AppBackendMode.supabase
           ? <Flashcard>[]
           : List<Flashcard>.of(MockData.flashcards);

  static const _ai = MockAiService();
  static const summaryMinimumContentCharacters = 80;
  static const summaryTooShortMessage =
      'Add more lecture text before generating a summary.';
  static const _fallbackSubject = Subject(
    id: 'missing-subject',
    name: 'Subject',
    description: 'Subject unavailable.',
    colorValue: 0xFF64748B,
  );

  final AppConfig config;
  final SubjectRepository subjectRepository;
  final MaterialRepository materialRepository;
  final FavoriteRepository favoriteRepository;
  final FlashcardRepository flashcardRepository;
  final SummaryRepository summaryRepository;
  final QuizRepository quizRepository;
  List<Subject> _subjects;
  List<StudyMaterial> _materials;
  List<Flashcard> _flashcards;
  List<Quiz> _quizzes = [];
  List<QuizAttempt> _quizAttempts = [];
  QuizAttempt? _latestQuizCompletion;
  final Set<String> _favoriteMaterialIds = {};
  final List<StudySession> _studySessions = [];
  int _materialCounter = 0;
  int _sessionCounter = 0;
  AppLanguagePreference _languagePreference = AppLanguagePreference.system;
  int _defaultFlashcardSessionSize = 5;
  int _dailyStudyGoalMinutes = 20;
  StudyDifficultyPreference _defaultDifficulty =
      StudyDifficultyPreference.medium;
  bool _isLoadingSubjects = false;
  bool _isCreatingSubject = false;
  String? _subjectSyncErrorMessage;
  bool _isLoadingMaterials = false;
  bool _isCreatingMaterial = false;
  String? _materialSyncErrorMessage;
  bool _isLoadingMaterialFavorites = false;
  bool _isUpdatingMaterialFavorite = false;
  String? _favoriteSyncErrorMessage;
  bool _isLoadingFlashcards = false;
  bool _isGeneratingFlashcards = false;
  bool _isSavingFlashcardReview = false;
  String? _flashcardSyncErrorMessage;
  String? _flashcardGenerationErrorMessage;
  String? _flashcardReviewErrorMessage;
  bool _isGeneratingSummary = false;
  String? _summaryGenerationErrorMessage;
  bool _isLoadingQuizzes = false;
  bool _isGeneratingQuiz = false;
  String? _quizSyncErrorMessage;
  String? _quizGenerationErrorMessage;
  bool _isLoadingQuizAttempts = false;
  bool _isSavingQuizAttempt = false;
  String? _quizAttemptSyncErrorMessage;

  List<Subject> get subjects => List.unmodifiable(_subjects);

  bool get isLoadingSubjects => _isLoadingSubjects;

  bool get isCreatingSubject => _isCreatingSubject;

  String? get subjectSyncErrorMessage => _subjectSyncErrorMessage;

  List<StudyMaterial> get materials => List.unmodifiable(_materials);

  bool get isLoadingMaterials => _isLoadingMaterials;

  bool get isCreatingMaterial => _isCreatingMaterial;

  String? get materialSyncErrorMessage => _materialSyncErrorMessage;

  List<StudyMaterial> get favoriteMaterials {
    return _materials
        .where((material) => _favoriteMaterialIds.contains(material.id))
        .toList();
  }

  bool get isLoadingMaterialFavorites => _isLoadingMaterialFavorites;

  bool get isUpdatingMaterialFavorite => _isUpdatingMaterialFavorite;

  String? get favoriteSyncErrorMessage => _favoriteSyncErrorMessage;

  bool get isLoadingFlashcards => _isLoadingFlashcards;

  bool get isGeneratingFlashcards => _isGeneratingFlashcards;

  bool get isSavingFlashcardReview => _isSavingFlashcardReview;

  String? get flashcardSyncErrorMessage => _flashcardSyncErrorMessage;

  String? get flashcardGenerationErrorMessage =>
      _flashcardGenerationErrorMessage;

  String? get flashcardReviewErrorMessage => _flashcardReviewErrorMessage;

  bool get isGeneratingSummary => _isGeneratingSummary;

  String? get summaryGenerationErrorMessage => _summaryGenerationErrorMessage;

  List<Quiz> get quizzes => List.unmodifiable(_quizzes);

  bool get isLoadingQuizzes => _isLoadingQuizzes;

  bool get isGeneratingQuiz => _isGeneratingQuiz;

  String? get quizSyncErrorMessage => _quizSyncErrorMessage;

  String? get quizGenerationErrorMessage => _quizGenerationErrorMessage;

  List<QuizAttempt> get quizAttempts => List.unmodifiable(_quizAttempts);

  QuizAttempt? get latestQuizAttempt => _quizAttempts.firstOrNull;

  QuizAttempt? get latestQuizCompletion => _latestQuizCompletion;

  bool get isLoadingQuizAttempts => _isLoadingQuizAttempts;

  bool get isSavingQuizAttempt => _isSavingQuizAttempt;

  String? get quizAttemptSyncErrorMessage => _quizAttemptSyncErrorMessage;

  AppLanguagePreference get languagePreference => _languagePreference;

  int get defaultFlashcardSessionSize => _defaultFlashcardSessionSize;

  int get dailyStudyGoalMinutes => _dailyStudyGoalMinutes;

  StudyDifficultyPreference get defaultDifficulty => _defaultDifficulty;

  Future<void> loadSubjectsFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _subjects = await subjectRepository.loadSubjects(
        user ??
            const AuthUser(
              id: 'mock-user',
              email: 'alex.student@example.test',
              displayName: 'Alex Student',
            ),
      );
      _subjectSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _subjects = [];
      _subjectSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingSubjects = true;
    _subjectSyncErrorMessage = null;
    notifyListeners();
    try {
      _subjects = await subjectRepository.loadSubjects(user);
    } catch (error) {
      _subjectSyncErrorMessage = _subjectMessageFor(error);
    } finally {
      _isLoadingSubjects = false;
      notifyListeners();
    }
  }

  Future<void> loadSyncedWorkspaceFor(AuthUser? user) async {
    await loadSubjectsFor(user);
    await loadMaterialsFor(user);
    await loadMaterialFavoritesFor(user);
    await loadFlashcardsFor(user);
    await loadQuizzesFor(user);
    await loadQuizAttemptsFor(user);
  }

  Future<void> loadMaterialsFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _materials = await materialRepository.loadMaterials(
        user ??
            const AuthUser(
              id: 'mock-user',
              email: 'alex.student@example.test',
              displayName: 'Alex Student',
            ),
      );
      _materialSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _materials = [];
      _materialSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingMaterials = true;
    _materialSyncErrorMessage = null;
    notifyListeners();
    try {
      _materials = await materialRepository.loadMaterials(user);
    } catch (error) {
      _materialSyncErrorMessage = _materialMessageFor(error);
    } finally {
      _isLoadingMaterials = false;
      notifyListeners();
    }
  }

  Future<bool> createSubjectFor(
    AuthUser? user, {
    required String name,
    required String description,
    required int colorValue,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _subjectSyncErrorMessage = 'Enter a subject name.';
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _subjectSyncErrorMessage = 'Log in to sync subjects.';
      notifyListeners();
      return false;
    }

    _isCreatingSubject = true;
    _subjectSyncErrorMessage = null;
    notifyListeners();
    try {
      final createdSubject = await subjectRepository.createSubject(
        user: effectiveUser,
        name: cleanName,
        description: description,
        colorValue: colorValue,
        sortOrder: _subjects.length,
      );
      _subjects = [..._subjects, createdSubject];
      return true;
    } catch (error) {
      _subjectSyncErrorMessage = _subjectMessageFor(error);
      return false;
    } finally {
      _isCreatingSubject = false;
      notifyListeners();
    }
  }

  Future<bool> createMaterialFor(
    AuthUser? user, {
    required String subjectId,
    required String title,
    required String content,
  }) async {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanContent.isEmpty) {
      _materialSyncErrorMessage = 'Enter a title and pasted text.';
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _materialSyncErrorMessage = 'Log in to sync materials.';
      notifyListeners();
      return false;
    }

    _isCreatingMaterial = true;
    _materialSyncErrorMessage = null;
    notifyListeners();
    try {
      final createdMaterial = await materialRepository.createMaterial(
        user: effectiveUser,
        subjectId: subjectId,
        title: cleanTitle,
        content: cleanContent,
      );
      _materials = [
        createdMaterial,
        for (final material in _materials)
          if (material.id != createdMaterial.id) material,
      ];
      return true;
    } catch (error) {
      _materialSyncErrorMessage = _materialMessageFor(error);
      return false;
    } finally {
      _isCreatingMaterial = false;
      notifyListeners();
    }
  }

  Future<void> loadMaterialFavoritesFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _favoriteMaterialIds
        ..clear()
        ..addAll(
          await favoriteRepository.loadMaterialFavoriteIds(
            user ??
                const AuthUser(
                  id: 'mock-user',
                  email: 'alex.student@example.test',
                  displayName: 'Alex Student',
                ),
          ),
        );
      _favoriteSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _favoriteMaterialIds.clear();
      _favoriteSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingMaterialFavorites = true;
    _favoriteSyncErrorMessage = null;
    notifyListeners();
    try {
      final favoriteIds = await favoriteRepository.loadMaterialFavoriteIds(
        user,
      );
      _favoriteMaterialIds
        ..clear()
        ..addAll(favoriteIds);
    } catch (error) {
      _favoriteSyncErrorMessage = _favoriteMessageFor(error);
    } finally {
      _isLoadingMaterialFavorites = false;
      notifyListeners();
    }
  }

  Future<void> loadFlashcardsFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _flashcards = await flashcardRepository.loadFlashcards(
        user ??
            const AuthUser(
              id: 'mock-user',
              email: 'alex.student@example.test',
              displayName: 'Alex Student',
            ),
      );
      _flashcardSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _flashcards = [];
      _flashcardSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingFlashcards = true;
    _flashcardSyncErrorMessage = null;
    notifyListeners();
    try {
      _flashcards = await flashcardRepository.loadFlashcards(user);
    } catch (error) {
      _flashcardSyncErrorMessage = _flashcardMessageFor(error);
    } finally {
      _isLoadingFlashcards = false;
      notifyListeners();
    }
  }

  Future<void> loadQuizzesFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _quizzes = await quizRepository.loadQuizzes(
        user ??
            const AuthUser(
              id: 'mock-user',
              email: 'alex.student@example.test',
              displayName: 'Alex Student',
            ),
      );
      _quizSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _quizzes = [];
      _quizSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingQuizzes = true;
    _quizSyncErrorMessage = null;
    notifyListeners();
    try {
      _quizzes = await quizRepository.loadQuizzes(user);
    } catch (error) {
      _quizSyncErrorMessage = _quizMessageFor(error);
    } finally {
      _isLoadingQuizzes = false;
      notifyListeners();
    }
  }

  Future<void> loadQuizAttemptsFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _quizAttempts = await quizRepository.loadQuizAttempts(
        user ??
            const AuthUser(
              id: 'mock-user',
              email: 'alex.student@example.test',
              displayName: 'Alex Student',
            ),
      );
      _quizAttemptSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _quizAttempts = [];
      _quizAttemptSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingQuizAttempts = true;
    _quizAttemptSyncErrorMessage = null;
    notifyListeners();
    try {
      _quizAttempts = await quizRepository.loadQuizAttempts(user);
    } catch (error) {
      _quizAttemptSyncErrorMessage = _quizAttemptMessageFor(error);
    } finally {
      _isLoadingQuizAttempts = false;
      notifyListeners();
    }
  }

  void clearSyncedSubjectsForSignOut() {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      return;
    }
    _subjects = [];
    _materials = [];
    _subjectSyncErrorMessage = null;
    _materialSyncErrorMessage = null;
    _favoriteSyncErrorMessage = null;
    _summaryGenerationErrorMessage = null;
    _flashcardSyncErrorMessage = null;
    _flashcardGenerationErrorMessage = null;
    _flashcardReviewErrorMessage = null;
    _quizSyncErrorMessage = null;
    _quizGenerationErrorMessage = null;
    _quizAttemptSyncErrorMessage = null;
    _isLoadingSubjects = false;
    _isCreatingSubject = false;
    _isLoadingMaterials = false;
    _isCreatingMaterial = false;
    _isLoadingMaterialFavorites = false;
    _isUpdatingMaterialFavorite = false;
    _isGeneratingSummary = false;
    _isLoadingFlashcards = false;
    _isGeneratingFlashcards = false;
    _isSavingFlashcardReview = false;
    _isLoadingQuizzes = false;
    _isGeneratingQuiz = false;
    _isLoadingQuizAttempts = false;
    _isSavingQuizAttempt = false;
    _favoriteMaterialIds.clear();
    _flashcards = [];
    _quizzes = [];
    _quizAttempts = [];
    _latestQuizCompletion = null;
    notifyListeners();
  }

  void clearSyncedWorkspaceForSignOut() {
    clearSyncedSubjectsForSignOut();
  }

  void setLanguagePreference(AppLanguagePreference value) {
    if (_languagePreference == value) {
      return;
    }
    _languagePreference = value;
    notifyListeners();
  }

  void setDefaultFlashcardSessionSize(int value) {
    if (_defaultFlashcardSessionSize == value) {
      return;
    }
    _defaultFlashcardSessionSize = value;
    notifyListeners();
  }

  void setDailyStudyGoalMinutes(int value) {
    if (_dailyStudyGoalMinutes == value) {
      return;
    }
    _dailyStudyGoalMinutes = value;
    notifyListeners();
  }

  void setDefaultDifficulty(StudyDifficultyPreference value) {
    if (_defaultDifficulty == value) {
      return;
    }
    _defaultDifficulty = value;
    notifyListeners();
  }

  List<StudyMaterial> materialsFor(String subjectId) {
    return _materials
        .where((material) => material.subjectId == subjectId)
        .toList();
  }

  StudyMaterial? materialById(String materialId) {
    for (final material in _materials) {
      if (material.id == materialId) {
        return material;
      }
    }
    return null;
  }

  Subject subjectFor(String subjectId) {
    return _subjectFor(subjectId);
  }

  List<Flashcard> flashcardsFor(String subjectId) {
    return _flashcards
        .where((flashcard) => flashcard.subjectId == subjectId)
        .toList();
  }

  List<Flashcard> flashcardsForMaterial(String materialId) {
    return _flashcards
        .where((flashcard) => flashcard.materialId == materialId)
        .toList();
  }

  List<Quiz> quizzesForMaterial(String materialId) {
    return _quizzes.where((quiz) => quiz.materialId == materialId).toList();
  }

  Quiz? latestQuizForMaterial(String materialId) {
    for (final quiz in _quizzes) {
      if (quiz.materialId == materialId) {
        return quiz;
      }
    }
    return null;
  }

  List<Flashcard> get favoriteFlashcards {
    if (config.effectiveBackendMode == AppBackendMode.supabase) {
      return const [];
    }
    return _flashcards.where((flashcard) => flashcard.isFavorite).toList();
  }

  bool isMaterialFavorite(String materialId) {
    return _favoriteMaterialIds.contains(materialId);
  }

  bool canGenerateSummaryForMaterial(StudyMaterial material) {
    return material.kind == MaterialKind.pastedText &&
        material.content.trim().length >= summaryMinimumContentCharacters;
  }

  bool canGenerateFlashcardsForMaterial(StudyMaterial material) {
    return material.kind == MaterialKind.pastedText &&
        material.content.trim().length >= summaryMinimumContentCharacters;
  }

  bool canGenerateQuizForMaterial(StudyMaterial material) {
    return material.kind == MaterialKind.pastedText &&
        material.content.trim().length >= summaryMinimumContentCharacters;
  }

  StudySession? get latestStudySession {
    if (_studySessions.isEmpty) {
      return null;
    }
    return _studySessions.last;
  }

  StudySession? sessionFor(String sessionId) {
    for (final session in _studySessions.reversed) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  List<WeakTopic> weakTopicsFor(String subjectId) {
    final session = latestStudySession;
    if (session != null && session.subjectId == subjectId) {
      return session.weakTopics;
    }
    final subject = _subjectForOrNull(subjectId);
    if (subject == null) {
      return const [];
    }
    return _ai.weakTopicsFor(subject);
  }

  List<Flashcard> get dueFlashcards {
    final session = latestStudySession;
    if (session != null) {
      return session.flashcards;
    }
    if (_subjects.isEmpty) {
      return const [];
    }
    return flashcardsFor(subjects.first.id);
  }

  List<LocalSearchResult> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final results = <LocalSearchResult>[];
    for (final subject in subjects) {
      if (subject.name.toLowerCase().contains(normalized)) {
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.subject,
            title: subject.name,
            subtitle: subject.description,
            subject: subject,
          ),
        );
      }
    }
    for (final material in _materials) {
      if (material.title.toLowerCase().contains(normalized)) {
        final subject = _subjectForOrNull(material.subjectId);
        if (subject == null) {
          continue;
        }
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.material,
            title: material.title,
            subtitle: '${subject.name} - ${material.createdLabel}',
            subject: subject,
            material: material,
          ),
        );
      }
    }
    for (final card in _flashcards) {
      if (card.front.toLowerCase().contains(normalized)) {
        final subject = _subjectForOrNull(card.subjectId);
        if (subject == null) {
          continue;
        }
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.flashcard,
            title: card.front,
            subtitle: '${subject.name} flashcard - ${card.topic}',
            subject: subject,
          ),
        );
      }
    }
    return results;
  }

  void addMaterial({
    required String subjectId,
    required String title,
    required String content,
  }) {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanContent.isEmpty) {
      return;
    }

    _materialCounter += 1;
    _materials.insert(
      0,
      StudyMaterial(
        id: 'local-material-$_materialCounter',
        subjectId: subjectId,
        title: cleanTitle,
        kind: MaterialKind.pastedText,
        content: cleanContent,
        createdLabel: 'Just now',
      ),
    );
    notifyListeners();
  }

  void toggleFavorite(String cardId) {
    _flashcards = [
      for (final card in _flashcards)
        card.id == cardId ? card.copyWith(isFavorite: !card.isFavorite) : card,
    ];
    notifyListeners();
  }

  Future<bool> toggleMaterialFavoriteFor(
    AuthUser? user,
    String materialId,
  ) async {
    final material = materialById(materialId);
    if (material == null) {
      _favoriteSyncErrorMessage = 'Material unavailable.';
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _favoriteSyncErrorMessage = 'Log in to sync favorites.';
      notifyListeners();
      return false;
    }

    final isFavorite = _favoriteMaterialIds.contains(material.id);
    _isUpdatingMaterialFavorite = true;
    _favoriteSyncErrorMessage = null;
    notifyListeners();
    try {
      if (isFavorite) {
        await favoriteRepository.removeMaterialFavorite(
          user: effectiveUser,
          materialId: material.id,
        );
        _favoriteMaterialIds.remove(material.id);
      } else {
        await favoriteRepository.addMaterialFavorite(
          user: effectiveUser,
          materialId: material.id,
        );
        _favoriteMaterialIds.add(material.id);
      }
      return true;
    } catch (error) {
      _favoriteSyncErrorMessage = _favoriteUpdateMessageFor(error);
      return false;
    } finally {
      _isUpdatingMaterialFavorite = false;
      notifyListeners();
    }
  }

  Future<bool> generateSummaryFor(AuthUser? user, String materialId) async {
    final material = materialById(materialId);
    if (material == null) {
      _summaryGenerationErrorMessage = 'Material unavailable.';
      notifyListeners();
      return false;
    }
    if (material.kind != MaterialKind.pastedText) {
      _summaryGenerationErrorMessage = 'Could not generate summary. Try again.';
      notifyListeners();
      return false;
    }
    if (material.content.trim().length < summaryMinimumContentCharacters) {
      _summaryGenerationErrorMessage = summaryTooShortMessage;
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _summaryGenerationErrorMessage = 'Could not generate summary. Try again.';
      notifyListeners();
      return false;
    }

    _isGeneratingSummary = true;
    _summaryGenerationErrorMessage = null;
    notifyListeners();
    try {
      final summary = await summaryRepository.generateSummary(
        user: effectiveUser,
        materialId: material.id,
      );
      _materials = [
        for (final item in _materials)
          item.id == material.id ? item.copyWith(summary: summary) : item,
      ];
      return true;
    } catch (error) {
      _summaryGenerationErrorMessage = _summaryMessageFor(error);
      return false;
    } finally {
      _isGeneratingSummary = false;
      notifyListeners();
    }
  }

  Future<bool> generateFlashcardsFor(
    AuthUser? user,
    String materialId, {
    int? count,
  }) async {
    final material = materialById(materialId);
    if (material == null) {
      _flashcardGenerationErrorMessage = 'Material unavailable.';
      notifyListeners();
      return false;
    }
    if (material.kind != MaterialKind.pastedText) {
      _flashcardGenerationErrorMessage =
          'Could not generate flashcards. Try again.';
      notifyListeners();
      return false;
    }
    if (!canGenerateFlashcardsForMaterial(material)) {
      _flashcardGenerationErrorMessage = flashcardsTooShortMessage;
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _flashcardGenerationErrorMessage =
          'Could not generate flashcards. Try again.';
      notifyListeners();
      return false;
    }

    final requestedCount = (count ?? _defaultFlashcardSessionSize)
        .clamp(1, 20)
        .toInt();
    _isGeneratingFlashcards = true;
    _flashcardGenerationErrorMessage = null;
    notifyListeners();
    try {
      final generatedCards = await flashcardRepository.generateFlashcards(
        user: effectiveUser,
        materialId: material.id,
        count: requestedCount,
      );
      final normalizedCards = [
        for (final card in generatedCards)
          card.copyWith(subjectId: material.subjectId, materialId: material.id),
      ];
      final generatedIds = normalizedCards.map((card) => card.id).toSet();
      _flashcards = [
        ...normalizedCards,
        for (final card in _flashcards)
          if (!generatedIds.contains(card.id)) card,
      ];
      return true;
    } catch (error) {
      _flashcardGenerationErrorMessage = _flashcardGenerateMessageFor(error);
      return false;
    } finally {
      _isGeneratingFlashcards = false;
      notifyListeners();
    }
  }

  Future<bool> generateQuizFor(
    AuthUser? user,
    String materialId, {
    int count = 5,
  }) async {
    final material = materialById(materialId);
    if (material == null) {
      _quizGenerationErrorMessage = 'Material unavailable.';
      notifyListeners();
      return false;
    }
    if (material.kind != MaterialKind.pastedText) {
      _quizGenerationErrorMessage = 'Could not generate quiz. Try again.';
      notifyListeners();
      return false;
    }
    if (!canGenerateQuizForMaterial(material)) {
      _quizGenerationErrorMessage = quizTooShortMessage;
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _quizGenerationErrorMessage = 'Could not generate quiz. Try again.';
      notifyListeners();
      return false;
    }

    final requestedCount = count.clamp(1, 20).toInt();
    _isGeneratingQuiz = true;
    _quizGenerationErrorMessage = null;
    notifyListeners();
    try {
      final generatedQuiz = await quizRepository.generateQuiz(
        user: effectiveUser,
        materialId: material.id,
        count: requestedCount,
      );
      final normalizedQuiz = Quiz(
        id: generatedQuiz.id,
        subjectId: material.subjectId,
        materialId: material.id,
        title: generatedQuiz.title,
        questions: [
          for (final question in generatedQuiz.questions)
            QuizQuestion(
              id: question.id,
              quizId: question.quizId ?? generatedQuiz.id,
              subjectId: material.subjectId,
              materialId: material.id,
              question: question.question,
              options: question.options,
              correctAnswer: question.correctAnswer,
              explanation: question.explanation,
              topic: question.topic.trim(),
              difficulty: question.difficulty,
            ),
        ],
      );
      _quizzes = [
        normalizedQuiz,
        for (final quiz in _quizzes)
          if (quiz.id != normalizedQuiz.id &&
              quiz.materialId != normalizedQuiz.materialId)
            quiz,
      ];
      return true;
    } catch (error) {
      _quizGenerationErrorMessage = _quizGenerateMessageFor(error);
      return false;
    } finally {
      _isGeneratingQuiz = false;
      notifyListeners();
    }
  }

  Future<bool> completeQuizFor(
    AuthUser? user, {
    required Quiz quiz,
    required Map<String, String> selectedAnswers,
    required DateTime startedAt,
    DateTime? completedAt,
  }) async {
    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    final finishedAt = (completedAt ?? DateTime.now()).toUtc();
    final answerRows = [
      for (final question in quiz.questions)
        QuizAttemptAnswer(
          questionId: question.id,
          question: question.question,
          selectedAnswer: selectedAnswers[question.id] ?? '',
          correctAnswer: question.correctAnswer,
          isCorrect: selectedAnswers[question.id] == question.correctAnswer,
          topic: question.topic.trim(),
        ),
    ];
    final correctQuestions = answerRows
        .where((answer) => answer.isCorrect)
        .length;
    final totalQuestions = answerRows.length;
    final weakTopicCounts = <String, int>{};
    for (final answer in answerRows.where((answer) => !answer.isCorrect)) {
      final topic = answer.topic.trim();
      if (topic.isEmpty) continue;
      weakTopicCounts.update(topic, (count) => count + 1, ifAbsent: () => 1);
    }
    final attempt = QuizAttempt(
      id: '',
      quizId: quiz.id,
      subjectId: quiz.subjectId,
      score: totalQuestions == 0
          ? 0
          : (correctQuestions / totalQuestions) * 100,
      totalQuestions: totalQuestions,
      correctQuestions: correctQuestions,
      startedAt: startedAt.toUtc(),
      completedAt: finishedAt,
      answers: answerRows,
      weakTopicsSnapshot: [
        for (final entry in weakTopicCounts.entries)
          QuizWeakTopicSnapshot(topic: entry.key, missCount: entry.value),
      ],
    );
    _latestQuizCompletion = attempt;

    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _quizAttemptSyncErrorMessage = 'Could not save this quiz attempt.';
      notifyListeners();
      return false;
    }

    _isSavingQuizAttempt = true;
    _quizAttemptSyncErrorMessage = null;
    notifyListeners();
    try {
      final savedAttempt = await quizRepository.saveQuizAttempt(
        user: effectiveUser,
        attempt: attempt,
      );
      _latestQuizCompletion = savedAttempt;
      _quizAttempts = [
        savedAttempt,
        for (final existing in _quizAttempts)
          if (existing.id != savedAttempt.id) existing,
      ];
      return true;
    } catch (error) {
      _quizAttemptSyncErrorMessage = _quizAttemptMessageFor(error);
      return false;
    } finally {
      _isSavingQuizAttempt = false;
      notifyListeners();
    }
  }

  Future<bool> reviewFlashcardFor(
    AuthUser? user,
    String cardId,
    FlashcardReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final card = _flashcardById(cardId);
    if (card == null) {
      _flashcardReviewErrorMessage = 'Could not save review progress.';
      notifyListeners();
      return false;
    }

    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _flashcardReviewErrorMessage = 'Could not save review progress.';
      notifyListeners();
      return false;
    }

    _isSavingFlashcardReview = true;
    _flashcardReviewErrorMessage = null;
    notifyListeners();
    try {
      final updatedCard = await flashcardRepository.updateReviewResult(
        user: effectiveUser,
        card: card,
        result: result,
        reviewedAt: reviewedAt ?? DateTime.now().toUtc(),
      );
      _flashcards = [
        for (final item in _flashcards) item.id == card.id ? updatedCard : item,
      ];
      return true;
    } catch (error) {
      _flashcardReviewErrorMessage = _flashcardReviewMessageFor(error);
      return false;
    } finally {
      _isSavingFlashcardReview = false;
      notifyListeners();
    }
  }

  StudySession createStudySession({
    required Subject subject,
    required LectureConfidence confidence,
    String? materialId,
  }) {
    final materials = materialsFor(subject.id);
    final selectedMaterialId = materialId ?? materials.firstOrNull?.id ?? '';
    final selectedMaterial = materialById(selectedMaterialId);
    final sessionNumber = ++_sessionCounter;
    final question = _quizFor(subject, selectedMaterial, sessionNumber);
    final session = StudySession(
      id: 'local-session-$sessionNumber',
      subjectId: subject.id,
      materialId: selectedMaterialId,
      confidence: confidence,
      summary: _summaryFor(subject, confidence, selectedMaterial),
      studyTimeBlocks: _timeBlocksFor(confidence),
      flashcards: _cardsFor(
        subject,
        confidence,
        selectedMaterial,
        sessionNumber,
      ),
      quizQuestion: question,
      weakTopics: _initialWeakTopicsFor(subject, confidence),
    );
    _studySessions.add(session);
    notifyListeners();
    return session;
  }

  void answerQuiz({required String sessionId, required String answer}) {
    final index = _studySessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) {
      return;
    }

    final session = _studySessions[index];
    final isCorrect = answer == session.quizQuestion.correctAnswer;
    final subject = _subjectForOrNull(session.subjectId);
    if (subject == null) {
      return;
    }
    final updatedWeakTopics = isCorrect
        ? _ai.weakTopicsFor(subject).take(1).toList()
        : [
            WeakTopic(
              subjectId: subject.id,
              title: session.flashcards.firstOrNull?.topic ?? 'Quick quiz',
              reason:
                  'You chose "$answer"; review why "${session.quizQuestion.correctAnswer}" is correct.',
            ),
            ..._ai.weakTopicsFor(subject).take(2),
          ];

    _studySessions[index] = session.copyWith(
      selectedAnswer: answer,
      quizScorePercent: isCorrect ? 100 : 0,
      weakTopics: updatedWeakTopics,
      feedback: isCorrect
          ? 'Correct. This topic is ready for a lighter review.'
          : 'Incorrect. Review the explanation, then retry the flashcards.',
    );
    notifyListeners();
  }

  Subject _subjectFor(String subjectId) {
    if (_subjects.isEmpty) {
      return _fallbackSubject;
    }
    return _subjects.firstWhere(
      (subject) => subject.id == subjectId,
      orElse: () => _fallbackSubject,
    );
  }

  Subject? _subjectForOrNull(String subjectId) {
    for (final subject in _subjects) {
      if (subject.id == subjectId) {
        return subject;
      }
    }
    return null;
  }

  Flashcard? _flashcardById(String cardId) {
    for (final card in _flashcards) {
      if (card.id == cardId) {
        return card;
      }
    }
    return null;
  }

  String _subjectMessageFor(Object error) {
    if (error is SubjectRepositoryException) {
      return error.message;
    }
    return 'Could not sync subjects. Try again.';
  }

  String _materialMessageFor(Object error) {
    if (error is MaterialRepositoryException) {
      return error.message;
    }
    return 'Could not sync materials. Try again.';
  }

  String _favoriteMessageFor(Object error) {
    if (error is FavoriteRepositoryException) {
      return error.message;
    }
    return 'Could not sync favorites. Try again.';
  }

  String _favoriteUpdateMessageFor(Object error) {
    if (error is FavoriteRepositoryException) {
      return error.message;
    }
    return 'Could not update favorite.';
  }

  String _summaryMessageFor(Object error) {
    if (error is SummaryRepositoryException) {
      return error.message;
    }
    return 'Could not generate summary. Try again.';
  }

  String _flashcardMessageFor(Object error) {
    if (error is FlashcardRepositoryException) {
      return error.message;
    }
    return 'Could not sync flashcards.';
  }

  String _flashcardGenerateMessageFor(Object error) {
    if (error is FlashcardRepositoryException) {
      return error.message;
    }
    return 'Could not generate flashcards. Try again.';
  }

  String _flashcardReviewMessageFor(Object error) {
    if (error is FlashcardRepositoryException) {
      return error.message;
    }
    return 'Could not save review progress.';
  }

  String _quizMessageFor(Object error) {
    if (error is QuizRepositoryException) {
      return error.message;
    }
    return 'Could not sync quizzes.';
  }

  String _quizGenerateMessageFor(Object error) {
    if (error is QuizRepositoryException) {
      return error.message;
    }
    return 'Could not generate quiz. Try again.';
  }

  String _quizAttemptMessageFor(Object error) {
    if (error is QuizRepositoryException) {
      return error.message;
    }
    return 'Could not save this quiz attempt.';
  }

  String _summaryFor(
    Subject subject,
    LectureConfidence confidence,
    StudyMaterial? material,
  ) {
    final base = _ai.summaryFor(subject);
    final sourceNote = material == null
        ? ''
        : ' Source "${material.title}" says: ${material.content}';
    return switch (confidence) {
      LectureConfidence.understoodEverything =>
        'Short review: $base$sourceNote Focus on one quick check and move on.',
      LectureConfidence.mostly =>
        'Normal review: $base$sourceNote Use flashcards, then answer the quick quiz.',
      LectureConfidence.aboutHalf =>
        'Practice review: $base$sourceNote Spend extra time on flashcards and quiz choices.',
      LectureConfidence.completelyLost =>
        'Simple explanation: start with the main idea in ${subject.name}, then connect one example from ${material?.title ?? 'the selected material'} before adding details.$sourceNote Take the longer guided review.',
    };
  }

  List<StudyTimeBlock> _timeBlocksFor(LectureConfidence confidence) {
    return switch (confidence) {
      LectureConfidence.understoodEverything => const [
        StudyTimeBlock(label: 'Summary', minutes: 3),
        StudyTimeBlock(label: 'Flashcards', minutes: 5),
        StudyTimeBlock(label: 'Quiz', minutes: 4),
      ],
      LectureConfidence.mostly => MockData.studyTimeBlocks,
      LectureConfidence.aboutHalf => const [
        StudyTimeBlock(label: 'Summary', minutes: 6),
        StudyTimeBlock(label: 'Flashcards', minutes: 14),
        StudyTimeBlock(label: 'Quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 8),
      ],
      LectureConfidence.completelyLost => const [
        StudyTimeBlock(label: 'Simple explanation', minutes: 10),
        StudyTimeBlock(label: 'Guided flashcards', minutes: 15),
        StudyTimeBlock(label: 'Quick quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 10),
      ],
    };
  }

  List<Flashcard> _cardsFor(
    Subject subject,
    LectureConfidence confidence,
    StudyMaterial? material,
    int sessionNumber,
  ) {
    final cards = flashcardsFor(subject.id);
    final sourceCards = material == null
        ? cards
        : [
            Flashcard(
              id: 'local-session-$sessionNumber-source-card-1',
              subjectId: subject.id,
              front: 'What is the key idea in "${material.title}"?',
              back: material.content.isEmpty
                  ? 'Review the selected material and identify its main point.'
                  : material.content,
              topic: material.title,
              isFavorite: false,
            ),
            ...cards,
          ];
    if (confidence == LectureConfidence.understoodEverything) {
      return sourceCards.take(1).toList();
    }
    if (confidence == LectureConfidence.aboutHalf ||
        confidence == LectureConfidence.completelyLost) {
      return [...sourceCards, ...sourceCards.take(1)];
    }
    return sourceCards;
  }

  QuizQuestion _quizFor(
    Subject subject,
    StudyMaterial? material,
    int sessionNumber,
  ) {
    final fallback = _ai.quizFor(subject).first;
    if (material == null) {
      return fallback;
    }
    return QuizQuestion(
      id: 'local-session-$sessionNumber-source-quiz',
      subjectId: subject.id,
      question: 'Which source did this study session use?',
      options: [
        material.title,
        'A generic ${subject.name} fallback',
        'An uploaded PDF',
        'A saved favorite',
      ],
      correctAnswer: material.title,
      explanation:
          'This local session was generated from "${material.title}", using its pasted content.',
      difficulty: fallback.difficulty,
    );
  }

  List<WeakTopic> _initialWeakTopicsFor(
    Subject subject,
    LectureConfidence confidence,
  ) {
    final topics = _ai.weakTopicsFor(subject);
    if (confidence == LectureConfidence.understoodEverything) {
      return topics.take(1).toList();
    }
    if (confidence == LectureConfidence.completelyLost) {
      return [
        WeakTopic(
          subjectId: subject.id,
          title: 'Core idea',
          reason: 'Start with a simpler explanation before practicing details.',
        ),
        ...topics,
      ];
    }
    return topics;
  }
}

enum AppLanguagePreference { system, english, german }

extension AppLanguagePreferenceLabel on AppLanguagePreference {
  String get label {
    return switch (this) {
      AppLanguagePreference.system => 'System default',
      AppLanguagePreference.english => 'English',
      AppLanguagePreference.german => 'Deutsch',
    };
  }
}

enum StudyDifficultyPreference { easy, medium, exam }

extension StudyDifficultyPreferenceLabel on StudyDifficultyPreference {
  String get label {
    return switch (this) {
      StudyDifficultyPreference.easy => 'easy',
      StudyDifficultyPreference.medium => 'medium',
      StudyDifficultyPreference.exam => 'exam',
    };
  }
}

enum LocalSearchResultKind { subject, material, flashcard }

class LocalSearchResult {
  const LocalSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.subject,
    this.material,
  });

  final LocalSearchResultKind kind;
  final String title;
  final String subtitle;
  final Subject subject;
  final StudyMaterial? material;
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  static AppState watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context.');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppStateScope>();
    final scope = element?.widget as AppStateScope?;
    assert(scope != null, 'No AppStateScope found in context.');
    return scope!.notifier!;
  }
}
