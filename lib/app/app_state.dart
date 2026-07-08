import 'package:flutter/material.dart';

import 'app_config.dart';
import '../core/models/flashcard.dart';
import '../core/models/material.dart';
import '../core/models/quiz_question.dart';
import '../core/models/study_session.dart';
import '../core/models/study_time_block.dart';
import '../core/models/subject.dart';
import '../core/models/weak_topic.dart';
import '../features/auth/auth_models.dart';
import '../features/materials/material_repository.dart';
import '../features/subjects/subject_repository.dart';
import '../mock/mock_ai_service.dart';
import '../mock/mock_data.dart';

class AppState extends ChangeNotifier {
  AppState({
    AppConfig? config,
    SubjectRepository? subjectRepository,
    MaterialRepository? materialRepository,
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
       _flashcards = List<Flashcard>.of(MockData.flashcards);

  static const _ai = MockAiService();
  static const _fallbackSubject = Subject(
    id: 'missing-subject',
    name: 'Subject',
    description: 'Subject unavailable.',
    colorValue: 0xFF64748B,
  );

  final AppConfig config;
  final SubjectRepository subjectRepository;
  final MaterialRepository materialRepository;
  List<Subject> _subjects;
  List<StudyMaterial> _materials;
  List<Flashcard> _flashcards;
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

  List<Subject> get subjects => List.unmodifiable(_subjects);

  bool get isLoadingSubjects => _isLoadingSubjects;

  bool get isCreatingSubject => _isCreatingSubject;

  String? get subjectSyncErrorMessage => _subjectSyncErrorMessage;

  List<StudyMaterial> get materials => List.unmodifiable(_materials);

  bool get isLoadingMaterials => _isLoadingMaterials;

  bool get isCreatingMaterial => _isCreatingMaterial;

  String? get materialSyncErrorMessage => _materialSyncErrorMessage;

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

  void clearSyncedSubjectsForSignOut() {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      return;
    }
    _subjects = [];
    _materials = [];
    _subjectSyncErrorMessage = null;
    _materialSyncErrorMessage = null;
    _isLoadingSubjects = false;
    _isCreatingSubject = false;
    _isLoadingMaterials = false;
    _isCreatingMaterial = false;
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

  List<Flashcard> get favoriteFlashcards {
    return _flashcards.where((flashcard) => flashcard.isFavorite).toList();
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
