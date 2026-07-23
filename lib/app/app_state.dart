import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'app_preferences.dart';
import '../core/models/flashcard.dart';
import '../core/models/material.dart';
import '../core/models/persisted_study_activity.dart';
import '../core/models/quiz.dart';
import '../core/models/quiz_attempt.dart';
import '../core/models/quiz_question.dart';
import '../core/models/study_session.dart';
import '../core/models/study_time_block.dart';
import '../core/models/subject.dart';
import '../core/models/weak_topic.dart';
import '../core/utils/uuid.dart';
import '../features/auth/auth_models.dart';
import '../features/deletion/deletion_models.dart';
import '../features/deletion/subject_deletion_repository.dart';
import '../features/favorites/favorite_repository.dart';
import '../features/flashcards/flashcard_repository.dart';
import '../features/generation/summary_repository.dart';
import '../features/materials/material_repository.dart';
import '../features/materials/material_analysis_repository.dart';
import '../features/materials/structured_summary.dart';
import '../features/materials/material_file_picker.dart';
import '../features/materials/material_upload.dart';
import '../features/materials/material_upload_repository.dart';
import '../features/materials/material_upload_queue.dart';
import '../features/materials/pdf_text_extraction_repository.dart';
import '../features/materials/image_text_extraction_repository.dart';
import '../features/materials/scanned_pdf_ocr_repository.dart';
import '../features/materials/material_lifecycle_repository.dart';
import '../features/materials/original_material_repository.dart';
import '../features/quizzes/quiz_repository.dart';
import '../features/study_sessions/study_activity_repository.dart';
import '../features/progress/weak_topic_repository.dart';
import '../features/progress/study_progress_repository.dart';
import '../core/models/knowledge_score.dart';
import '../features/subjects/subject_repository.dart';
import '../mock/mock_ai_service.dart';
import '../mock/mock_data.dart';

enum AnalysisExplicitAction { preflight, confirmation, retry }

class AppState extends ChangeNotifier {
  AppState({
    AppConfig? config,
    SubjectRepository? subjectRepository,
    MaterialRepository? materialRepository,
    MaterialAnalysisRepository? materialAnalysisRepository,
    MaterialUploadRepository? materialUploadRepository,
    PdfTextExtractionRepository? pdfTextExtractionRepository,
    ImageTextExtractionRepository? imageTextExtractionRepository,
    ScannedPdfOcrRepository? scannedPdfOcrRepository,
    MaterialLifecycleRepository? materialLifecycleRepository,
    OriginalMaterialRepository? originalMaterialRepository,
    MaterialFilePicker? materialFilePicker,
    String Function()? materialIdGenerator,
    FavoriteRepository? favoriteRepository,
    FlashcardRepository? flashcardRepository,
    SummaryRepository? summaryRepository,
    QuizRepository? quizRepository,
    StudyActivityRepository? studyActivityRepository,
    WeakTopicRepository? weakTopicRepository,
    StudyProgressRepository? studyProgressRepository,
    SubjectDeletionRepository? subjectDeletionRepository,
    AppPreferencesStore? preferencesStore,
    Future<void> Function(Duration)? analysisDelay,
    DateTime Function()? analysisNow,
  }) : config = config ?? AppConfig.fromValues(),
       preferencesStore =
           preferencesStore ?? const SharedPreferencesAppPreferencesStore(),
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
       materialUploadRepository =
           materialUploadRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyMaterialUploadRepository()
               : MockMaterialUploadRepository()),
       materialAnalysisRepository =
           materialAnalysisRepository ??
           const EmptyMaterialAnalysisRepository(),
       materialFilePicker =
           materialFilePicker ?? const PlatformMaterialFilePicker(),
       pdfTextExtractionRepository =
           pdfTextExtractionRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyPdfTextExtractionRepository()
               : const MockPdfTextExtractionRepository()),
       imageTextExtractionRepository =
           imageTextExtractionRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyImageTextExtractionRepository()
               : const MockImageTextExtractionRepository()),
       scannedPdfOcrRepository =
           scannedPdfOcrRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyScannedPdfOcrRepository()
               : const MockScannedPdfOcrRepository()),
       materialLifecycleRepository =
           materialLifecycleRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyMaterialLifecycleRepository()
               : const MockMaterialLifecycleRepository()),
       originalMaterialRepository =
           originalMaterialRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyOriginalMaterialRepository()
               : MockOriginalMaterialRepository()),
       materialIdGenerator = materialIdGenerator ?? newUuidV4,
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
               : MockFlashcardRepository()),
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
       studyActivityRepository =
           studyActivityRepository ?? const EmptyStudyActivityRepository(),
       weakTopicRepository =
           weakTopicRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptyWeakTopicRepository()
               : const MockWeakTopicRepository()),
       studyProgressRepository =
           studyProgressRepository ?? const EmptyStudyProgressRepository(),
       subjectDeletionRepository =
           subjectDeletionRepository ??
           ((config ?? AppConfig.fromValues()).effectiveBackendMode ==
                   AppBackendMode.supabase
               ? const EmptySubjectDeletionRepository()
               : const MockSubjectDeletionRepository()),
       _analysisDelay = analysisDelay ?? Future<void>.delayed,
       _analysisNow = analysisNow ?? DateTime.now,
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
  final AppPreferencesStore preferencesStore;
  final SubjectRepository subjectRepository;
  final MaterialRepository materialRepository;
  final MaterialAnalysisRepository materialAnalysisRepository;
  final MaterialUploadRepository materialUploadRepository;
  final PdfTextExtractionRepository pdfTextExtractionRepository;
  final ImageTextExtractionRepository imageTextExtractionRepository;
  final ScannedPdfOcrRepository scannedPdfOcrRepository;
  final MaterialLifecycleRepository materialLifecycleRepository;
  final OriginalMaterialRepository originalMaterialRepository;
  final MaterialFilePicker materialFilePicker;
  final String Function() materialIdGenerator;
  late final MaterialUploadQueueController materialUploadQueue =
      MaterialUploadQueueController(
        repository: materialUploadRepository,
        queueIdGenerator: newUuidV4,
        materialIdGenerator: materialIdGenerator,
        processMaterial: _processQueuedMaterial,
        retryMaterialAnalysis: (user, materialId) =>
            retryMaterialAnalysis(user, materialId),
        onMaterialChanged: _upsertQueuedMaterial,
      );
  final FavoriteRepository favoriteRepository;
  final FlashcardRepository flashcardRepository;
  final SummaryRepository summaryRepository;
  final QuizRepository quizRepository;
  final StudyActivityRepository studyActivityRepository;
  final WeakTopicRepository weakTopicRepository;
  final StudyProgressRepository studyProgressRepository;
  final SubjectDeletionRepository subjectDeletionRepository;
  final Future<void> Function(Duration) _analysisDelay;
  final DateTime Function() _analysisNow;
  List<Subject> _subjects;
  List<StudyMaterial> _materials;
  List<Flashcard> _flashcards;
  List<Quiz> _quizzes = [];
  List<QuizAttempt> _quizAttempts = [];
  List<PersistedStudyActivity> _activeStudyActivities = [];
  List<PersistedStudyActivity> _completedStudyActivities = [];
  String? _studyActivityErrorMessage;
  List<CumulativeWeakTopic> _cumulativeWeakTopics = [];
  StudyProgress? _studyProgress;
  bool _isLoadingStudyProgress = false;
  String? _studyProgressErrorMessage;
  QuizAttempt? _latestQuizCompletion;
  final Set<String> _favoriteMaterialIds = {};
  final Set<String> _favoriteFlashcardIds = {};
  final List<StudySession> _studySessions = [];
  final Set<String> _deletingMaterialIds = {};
  final Set<String> _deletingSubjectIds = {};
  final Map<String, DeletionSafeCode> _subjectDeletionErrors = {};
  final Map<String, String> _materialLifecycleErrors = {};
  final Map<String, String> _staleMaterialProcessors = {};
  final Map<String, MaterialAnalysisStatus> _analysisStatuses = {};
  final Map<String, AnalysisErrorCode> _analysisErrors = {};
  final Map<String, int> _analysisGenerations = {};
  final Map<String, int> _analysisLoops = {};
  final Map<String, Future<MaterialAnalysisStatus>> _analysisAdvanceTasks = {};
  final Set<String> _analysisPending = {};
  final Map<String, Future<void>> _analysisObservations = {};
  final Map<String, Future<void>> _analysisForcedObservations = {};
  final Set<String> _analysisReconciling = {};
  final Set<String> _analysisStopped = {};
  final Map<String, _AnalysisRetryGuard> _analysisRetryGuards = {};
  final Map<String, _AnalysisActionGuard> _analysisActions = {};
  Future<void>? _analysisResumeOperation;
  Future<void> _studySessionPersistence = Future.value();
  Future<void> _studySessionRestoration = Future.value();
  String? _analysisUserId;
  AuthUser? _analysisUser;
  bool _analysisForegrounded = true;
  int _materialCounter = 0;
  int _sessionCounter = 0;
  AppLanguagePreference _languagePreference = AppLanguagePreference.system;
  AppAppearancePreference _appearancePreference =
      AppAppearancePreference.system;
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
  bool _isUploadingMaterial = false;
  double? _uploadProgress;
  String? _uploadStage;
  String? _uploadError;
  final Set<String> _extractingPdfIds = {};
  final Map<String, String> _pdfExtractionErrors = {};
  final Set<String> _scanningPdfIds = {};
  final Map<String, String> _scannedPdfOcrErrors = {};
  final Set<String> _extractingImageIds = {};
  final Map<String, String> _imageExtractionErrors = {};
  String? _materialWorkSessionUserId;
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
  bool _isLoadingCumulativeWeakTopics = false;
  String? _weakTopicSyncErrorMessage;

  List<Subject> get subjects => List.unmodifiable(_subjects);

  bool get isLoadingSubjects => _isLoadingSubjects;

  bool get isCreatingSubject => _isCreatingSubject;

  String? get subjectSyncErrorMessage => _subjectSyncErrorMessage;

  List<StudyMaterial> get materials => List.unmodifiable(_materials);

  @override
  void dispose() {
    _analysisForegrounded = false;
    _analysisUserId = null;
    _analysisUser = null;
    for (final id in _analysisGenerations.keys.toList()) {
      _nextAnalysis(id);
    }
    _analysisObservations.clear();
    _analysisActions.clear();
    materialUploadQueue.dispose();
    super.dispose();
  }

  bool get isLoadingMaterials => _isLoadingMaterials;

  bool get isCreatingMaterial => _isCreatingMaterial;

  String? get materialSyncErrorMessage => _materialSyncErrorMessage;

  bool get isUploadingMaterial => _isUploadingMaterial;

  double? get uploadProgress => _uploadProgress;

  String? get uploadStage => _uploadStage;

  String? get uploadError => _uploadError;

  bool isDeletingMaterial(String materialId) =>
      _deletingMaterialIds.contains(materialId);
  String? materialLifecycleErrorFor(String materialId) =>
      _materialLifecycleErrors[materialId];
  bool isDeletingSubject(String subjectId) =>
      _deletingSubjectIds.contains(subjectId);
  DeletionSafeCode? subjectDeletionErrorFor(String subjectId) =>
      _subjectDeletionErrors[subjectId];
  bool isSubjectAvailable(String subjectId) =>
      !_deletingSubjectIds.contains(subjectId) &&
      _subjects.any((item) => item.id == subjectId);
  bool isMaterialRecoveryEligible(String materialId) =>
      _staleMaterialProcessors.containsKey(materialId);

  bool isExtractingPdf(String materialId) =>
      _extractingPdfIds.contains(materialId);

  String? pdfExtractionErrorFor(String materialId) =>
      _pdfExtractionErrors[materialId];
  bool isScanningPdf(String materialId) => _scanningPdfIds.contains(materialId);
  String? scannedPdfOcrErrorFor(String materialId) =>
      _scannedPdfOcrErrors[materialId];
  bool isScannedPdfOcrAvailable(StudyMaterial material) =>
      material.kind == MaterialKind.pdf &&
      material.sourceKind == MaterialSourceKind.upload &&
      material.processingStatus == MaterialProcessingStatus.failed &&
      !material.hasContentText &&
      const {
        'ocr_available',
        'mixed_ocr_available',
      }.contains(material.pdfExtraction?.classification) &&
      material.scannedPdfOcr?.extractedAt == null;

  bool isExtractingImage(String materialId) =>
      _extractingImageIds.contains(materialId);
  String? imageExtractionErrorFor(String materialId) =>
      _imageExtractionErrors[materialId];
  MaterialAnalysisStatus? analysisStatusFor(String id) => _analysisStatuses[id];
  AnalysisErrorCode? analysisErrorFor(String id) => _analysisErrors[id];
  int get activeAnalysisLoopCount => _analysisLoops.length;
  bool isMaterialAnalysisActionInFlight(String id) =>
      _analysisActions.containsKey(id);
  AnalysisExplicitAction? materialAnalysisActionFor(String id) =>
      _analysisActions[id]?.action;

  Future<void> observeMaterialAnalysis(
    AuthUser? user,
    String id, {
    bool force = false,
  }) {
    if (user == null) return Future.value();
    _bindAnalysis(user);
    if (!force &&
        (_analysisLoops.containsKey(id) ||
            const {
              AnalysisErrorCode.documentTooLarge,
              AnalysisErrorCode.invalidDocument,
              AnalysisErrorCode.unsupportedSource,
              AnalysisErrorCode.corruptDocument,
            }.contains(_analysisErrors[id]))) {
      return Future.value();
    }
    if (force) return _forceObserveMaterialAnalysis(user, id);
    return _startMaterialAnalysisObservation(user, id);
  }

  Future<void> _startMaterialAnalysisObservation(AuthUser user, String id) {
    _analysisStopped.remove(id);
    final existing = _analysisObservations[id];
    if (existing != null) return existing;
    final operation = _observeMaterialAnalysis(user, id);
    _analysisObservations[id] = operation;
    return operation.whenComplete(() {
      if (identical(_analysisObservations[id], operation)) {
        _analysisObservations.remove(id);
      }
    });
  }

  Future<void> _forceObserveMaterialAnalysis(AuthUser user, String id) {
    final queued = _analysisForcedObservations[id];
    if (queued != null) return queued;
    late final Future<void> operation;
    operation = (() async {
      _analysisReconciling.add(id);
      try {
        final existingObservation = _analysisObservations[id];
        if (existingObservation != null) await existingObservation;
        if (_analysisUserId != user.id) return;
        final inFlightAdvance = _analysisAdvanceTasks[id];
        if (inFlightAdvance != null) {
          _nextAnalysis(id);
          _analysisLoops.remove(id);
          try {
            await inFlightAdvance;
          } catch (_) {
            // The authoritative fetch below decides whether work remains.
          }
        }
        if (_analysisUserId != user.id) return;
        if (inFlightAdvance == null && _analysisLoops.containsKey(id)) {
          await _refreshMaterialAnalysisStatus(user, id);
        } else {
          await _startMaterialAnalysisObservation(user, id);
        }
      } finally {
        _analysisReconciling.remove(id);
        if (_analysisForegrounded && _analysisUserId == user.id) {
          _scheduleAnalysis(user, id);
        }
      }
    })();
    _analysisForcedObservations[id] = operation;
    return operation.whenComplete(() {
      if (identical(_analysisForcedObservations[id], operation)) {
        _analysisForcedObservations.remove(id);
      }
    });
  }

  Future<void> _refreshMaterialAnalysisStatus(AuthUser user, String id) async {
    try {
      final status = await materialAnalysisRepository.fetchStatus(
        user: user,
        materialId: id,
      );
      if (_analysisUserId != user.id || _analysisStopped.contains(id)) return;
      _publishAnalysisStatus(id, status);
      if (status.isTerminal || status.confirmationRequired) {
        _analysisRetryGuards.remove(id);
        _analysisErrors.remove(id);
        _nextAnalysis(id);
        _analysisLoops.remove(id);
      } else {
        final retryGuard = _analysisRetryGuards[id];
        if (retryGuard == null ||
            !_analysisNow().isBefore(retryGuard.nextAllowedAt)) {
          _analysisErrors.remove(id);
        }
      }
      notifyListeners();
    } on MaterialAnalysisException catch (error) {
      if (_analysisUserId != user.id || _analysisStopped.contains(id)) return;
      _analysisErrors.putIfAbsent(id, () => error.code);
      notifyListeners();
    }
  }

  Future<void> _observeMaterialAnalysis(AuthUser user, String id) async {
    final generation = _nextAnalysis(id);
    try {
      final status = await materialAnalysisRepository.fetchStatus(
        user: user,
        materialId: id,
      );
      if (!_currentAnalysis(user, id, generation)) return;
      _publishAnalysisStatus(id, status);
      final retryGuard = _analysisRetryGuards[id];
      if (status.isTerminal || status.confirmationRequired) {
        _analysisRetryGuards.remove(id);
        _analysisErrors.remove(id);
      } else if (retryGuard == null ||
          !_analysisNow().isBefore(retryGuard.nextAllowedAt)) {
        _analysisErrors.remove(id);
      }
      notifyListeners();
      _scheduleAnalysis(user, id);
    } on MaterialAnalysisException catch (e) {
      if (!_currentAnalysis(user, id, generation)) return;
      if (e.code == AnalysisErrorCode.statusNotFound) {
        await _action(
          user,
          id,
          AnalysisExplicitAction.preflight,
          () => materialAnalysisRepository.prepare(
            user: user,
            materialId: id,
            mode: AnalysisProcessingMode.recommended,
            confirmLargeDocument: false,
          ),
        );
        return;
      }
      _analysisErrors.putIfAbsent(id, () => e.code);
      notifyListeners();
    }
  }

  void stopObservingMaterialAnalysis(String id) {
    _analysisStopped.add(id);
    _nextAnalysis(id);
    _analysisLoops.remove(id);
    _analysisPending.remove(id);
    _analysisForcedObservations.remove(id);
    _analysisReconciling.remove(id);
    _analysisRetryGuards.remove(id);
  }

  void setAnalysisLifecycleForegrounded(bool value) {
    if (_analysisForegrounded == value) return;
    _analysisForegrounded = value;
    if (!value) {
      for (final id in _analysisLoops.keys.toList()) {
        _nextAnalysis(id);
      }
      return;
    }
    final user = _analysisUser;
    if (user != null) {
      for (final id in _analysisStatuses.keys.toList()) {
        unawaited(observeMaterialAnalysis(user, id, force: true));
      }
    }
  }

  Future<void> resumeMaterialAnalyses(AuthUser? user) {
    if (user == null) {
      setAnalysisLifecycleForegrounded(true);
      return Future.value();
    }
    final existing = _analysisResumeOperation;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _resumeMaterialAnalyses(user);
    _analysisResumeOperation = operation;
    return operation.whenComplete(() {
      if (identical(_analysisResumeOperation, operation)) {
        _analysisResumeOperation = null;
      }
    });
  }

  Future<void> _resumeMaterialAnalyses(AuthUser user) async {
    _bindAnalysis(user);
    await loadMaterialsFor(user);
    if (_analysisUserId != user.id) return;
    _analysisForegrounded = true;
    await _reconcilePersistedMaterialAnalyses(user);
  }

  Future<void> _reconcilePersistedMaterialAnalyses(AuthUser user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase ||
        materialAnalysisRepository is EmptyMaterialAnalysisRepository ||
        _analysisUserId != user.id) {
      return;
    }
    final candidates = _materials
        .where(
          (material) =>
              material.sourceKind == MaterialSourceKind.upload &&
              (material.kind == MaterialKind.pdf ||
                  material.kind == MaterialKind.image) &&
              (material.processingStatus == MaterialProcessingStatus.pending ||
                  material.processingStatus ==
                      MaterialProcessingStatus.processing),
        )
        .map((material) => material.id)
        .toSet();
    await Future.wait(
      candidates.map((id) => observeMaterialAnalysis(user, id, force: true)),
    );
  }

  Future<bool> confirmLargeMaterialAnalysis(AuthUser? user, String id) async {
    final s = _analysisStatuses[id];
    if (user == null ||
        s == null ||
        !s.confirmationRequired ||
        s.pageCount < 21 ||
        s.pageCount > 100) {
      return false;
    }
    return _action(
      user,
      id,
      AnalysisExplicitAction.confirmation,
      () => materialAnalysisRepository.prepare(
        user: user,
        materialId: id,
        mode: s.processingMode,
        confirmLargeDocument: true,
      ),
    );
  }

  Future<bool> retryMaterialAnalysis(AuthUser? user, String id) async {
    final s = _analysisStatuses[id];
    if (user == null ||
        s == null ||
        s.state != AnalysisState.userRetryRequired ||
        !s.canRetry) {
      return false;
    }
    return _action(
      user,
      id,
      AnalysisExplicitAction.retry,
      () => materialAnalysisRepository.retry(user: user, materialId: id),
    );
  }

  Future<bool> _action(
    AuthUser user,
    String id,
    AnalysisExplicitAction action,
    Future<MaterialAnalysisStatus> Function() call,
  ) async {
    _bindAnalysis(user);
    final guard = _beginAnalysisAction(id, action);
    if (guard == null) return false;
    final g = _nextAnalysis(id);
    try {
      final s = await call();
      if (!_currentAnalysis(user, id, g)) return false;
      _publishAnalysisStatus(id, s, allowRestart: true);
      _analysisErrors.remove(id);
      notifyListeners();
      _scheduleAnalysis(user, id);
      return true;
    } on MaterialAnalysisException catch (error) {
      if (_currentAnalysis(user, id, g)) {
        _analysisErrors[id] = error.code;
        notifyListeners();
      }
      return false;
    } finally {
      _endAnalysisAction(guard);
    }
  }

  _AnalysisActionGuard? _beginAnalysisAction(
    String id,
    AnalysisExplicitAction action,
  ) {
    if (_analysisActions.containsKey(id)) return null;
    final guard = _AnalysisActionGuard(id: id, action: action);
    _analysisActions[id] = guard;
    notifyListeners();
    return guard;
  }

  void _endAnalysisAction(_AnalysisActionGuard guard) {
    if (identical(_analysisActions[guard.id], guard)) {
      _analysisActions.remove(guard.id);
      notifyListeners();
    }
  }

  void _bindAnalysis(AuthUser user) {
    if (_analysisUserId == user.id) {
      _analysisUser = user;
      return;
    }
    _analysisUserId = user.id;
    _analysisUser = user;
    _analysisStatuses.clear();
    _analysisErrors.clear();
    for (final id in _analysisGenerations.keys.toList()) {
      _nextAnalysis(id);
    }
    _analysisLoops.clear();
    _analysisAdvanceTasks.clear();
    _analysisPending.clear();
    _analysisObservations.clear();
    _analysisForcedObservations.clear();
    _analysisReconciling.clear();
    _analysisStopped.clear();
    _analysisRetryGuards.clear();
    _analysisActions.clear();
    _analysisResumeOperation = null;
  }

  int _nextAnalysis(String id) =>
      _analysisGenerations.update(id, (v) => v + 1, ifAbsent: () => 1);
  bool _currentAnalysis(AuthUser user, String id, int g) =>
      _analysisUserId == user.id && _analysisGenerations[id] == g;

  void _publishAnalysisStatus(
    String id,
    MaterialAnalysisStatus next, {
    bool allowRestart = false,
  }) {
    final current = _analysisStatuses[id];
    final currentIsFinal =
        current != null &&
        (current.state == AnalysisState.completed ||
            current.state == AnalysisState.completedWithWarnings ||
            (current.state == AnalysisState.failed && !current.canRetry));
    if (!allowRestart && currentIsFinal && !next.isTerminal) return;
    _analysisStatuses[id] = next;
    materialUploadQueue.acceptAnalysisStatus(id, next);
    if (!next.isTerminal) return;
    final processingStatus = switch (next.state) {
      AnalysisState.completed ||
      AnalysisState.completedWithWarnings => MaterialProcessingStatus.ready,
      AnalysisState.failed => MaterialProcessingStatus.failed,
      _ => null,
    };
    if (processingStatus == null) return;
    _materials = [
      for (final material in _materials)
        if (material.id == id)
          material.copyWith(processingStatus: processingStatus)
        else
          material,
    ];
  }

  void _scheduleAnalysis(AuthUser user, String id) {
    final s = _analysisStatuses[id];
    final retryGuard = _analysisRetryGuards[id];
    if (retryGuard != null) {
      if (_analysisNow().isBefore(retryGuard.nextAllowedAt)) return;
      _analysisRetryGuards.remove(id);
    }
    if (!_analysisForegrounded ||
        _analysisReconciling.contains(id) ||
        _analysisStopped.contains(id) ||
        s == null ||
        s.isTerminal ||
        s.confirmationRequired) {
      return;
    }
    if (_analysisLoops.containsKey(id)) return;
    if (_analysisLoops.length >= 2) {
      _analysisPending.add(id);
      return;
    }
    _analysisPending.remove(id);
    final g = _nextAnalysis(id);
    _analysisLoops[id] = g;
    unawaited(_runAnalysis(user, id, g));
  }

  Future<void> _runAnalysis(AuthUser user, String id, int g) async {
    var delay = const Duration(milliseconds: 700);
    try {
      while (_analysisForegrounded && _currentAnalysis(user, id, g)) {
        final before = _analysisStatuses[id];
        if (before == null ||
            before.isTerminal ||
            before.confirmationRequired) {
          break;
        }
        try {
          late final Future<MaterialAnalysisStatus> advance;
          advance = materialAnalysisRepository.advance(
            user: user,
            materialId: id,
          );
          _analysisAdvanceTasks[id] = advance;
          late final MaterialAnalysisStatus s;
          try {
            s = await advance;
          } finally {
            if (identical(_analysisAdvanceTasks[id], advance)) {
              _analysisAdvanceTasks.remove(id);
            }
          }
          if (!_currentAnalysis(user, id, g)) break;
          _publishAnalysisStatus(id, s);
          _analysisRetryGuards.remove(id);
          _analysisErrors.remove(id);
          notifyListeners();
          if (s.isTerminal || s.confirmationRequired) break;
          delay = Duration(
            milliseconds: s.retryAfterSeconds == null
                ? 700
                : (s.retryAfterSeconds! * 1000).clamp(700, 30000),
          );
        } on MaterialAnalysisException catch (error) {
          if (!_currentAnalysis(user, id, g)) break;
          if (error.code == AnalysisErrorCode.requestFailed) {
            _analysisErrors[id] = error.code;
            _analysisRetryGuards[id] = _AnalysisRetryGuard(
              failures: 1,
              nextAllowedAt: _analysisNow().add(const Duration(seconds: 30)),
            );
            notifyListeners();
            break;
          }
          if (!_transientAnalysisErrors.contains(error.code)) {
            _analysisErrors[id] = error.code;
            notifyListeners();
            break;
          }
          final failures = (_analysisRetryGuards[id]?.failures ?? 0) + 1;
          final backoff = Duration(
            seconds: switch (failures) {
              1 => 1,
              2 => 2,
              _ => 4,
            },
          );
          _analysisErrors[id] = error.code;
          _analysisRetryGuards[id] = _AnalysisRetryGuard(
            failures: failures,
            nextAllowedAt: _analysisNow().add(backoff),
          );
          notifyListeners();
          if (failures >= 3) break;
          await _analysisDelay(backoff);
          if (!_currentAnalysis(user, id, g)) break;
          try {
            final refreshed = await materialAnalysisRepository.fetchStatus(
              user: user,
              materialId: id,
            );
            if (!_currentAnalysis(user, id, g)) break;
            _publishAnalysisStatus(id, refreshed);
            notifyListeners();
            if (refreshed.isTerminal || refreshed.confirmationRequired) break;
          } on MaterialAnalysisException catch (refreshError) {
            if (_currentAnalysis(user, id, g)) {
              _analysisErrors[id] = refreshError.code;
              notifyListeners();
            }
            break;
          }
          continue;
        }
        await _analysisDelay(delay);
      }
    } finally {
      if (_analysisLoops[id] == g) {
        _analysisLoops.remove(id);
      }
      if (_analysisForegrounded && _analysisUserId == user.id) {
        _scheduleAnalysis(user, id);
        for (final next in _analysisPending.toList()) {
          if (_analysisLoops.length >= 2) break;
          _scheduleAnalysis(user, next);
        }
      }
      notifyListeners();
    }
  }

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

  List<CumulativeWeakTopic> get cumulativeWeakTopics =>
      List.unmodifiable(_cumulativeWeakTopics);

  List<CumulativeWeakTopic> cumulativeWeakTopicsFor(String subjectId) {
    return _cumulativeWeakTopics
        .where((topic) => topic.subjectId == subjectId)
        .toList();
  }

  bool get isLoadingCumulativeWeakTopics => _isLoadingCumulativeWeakTopics;

  String? get weakTopicSyncErrorMessage => _weakTopicSyncErrorMessage;

  AppLanguagePreference get languagePreference => _languagePreference;

  Locale? get appLocale => _languagePreference.locale;

  AppAppearancePreference get appearancePreference => _appearancePreference;

  ThemeMode get themeMode => _appearancePreference.themeMode;

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
    if (_materialWorkSessionUserId != user?.id) {
      _materialWorkSessionUserId = user?.id;
      _clearMaterialWorkState();
      _studySessions.clear();
      _sessionCounter = 0;
    }
    materialUploadQueue.bindSession(user?.id);
    if (user != null) _bindAnalysis(user);
    await loadSubjectsFor(user);
    await loadMaterialsFor(user);
    await loadMaterialFavoritesFor(user);
    await loadFlashcardsFor(user);
    await loadQuizzesFor(user);
    await loadQuizAttemptsFor(user);
    await loadStudyActivitiesFor(user);
    await loadCumulativeWeakTopicsFor(user);
    await loadStudyProgressFor(user);
    if (user != null) {
      _studySessionRestoration = _restoreActiveStudySession(user);
      unawaited(_studySessionRestoration);
    }
    if (user != null) {
      _analysisForegrounded = true;
      await _reconcilePersistedMaterialAnalyses(user);
    }
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

  Future<SelectedMaterialFile?> pickMaterialFile(MaterialKind kind) {
    return materialFilePicker.pick(kind);
  }

  Future<MaterialFilePickerBatch?> pickMaterialFiles(MaterialKind kind) {
    final picker = materialFilePicker;
    if (picker is MultiMaterialFilePicker) return picker.pickMultiple(kind);
    return picker.pick(kind).then((file) {
      if (file == null) return null;
      return validateMaterialFileBatch(
        batchToken: newUuidV4(),
        files: [file],
        expectedKind: kind,
      );
    });
  }

  bool enqueueMaterialBatch(
    AuthUser? user, {
    required String subjectId,
    required MaterialKind kind,
    required MaterialFilePickerBatch batch,
    AnalysisProcessingMode analysisMode = AnalysisProcessingMode.recommended,
  }) {
    if (kind == MaterialKind.pastedText) return false;
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      return false;
    }
    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    return materialUploadQueue.enqueueBatch(
      user: effectiveUser,
      subjectId: subjectId,
      kind: kind,
      batch: batch,
      analysisMode: analysisMode,
    );
  }

  Future<bool> uploadMaterialFor(
    AuthUser? user, {
    required String subjectId,
    required MaterialKind kind,
    required SelectedMaterialFile selectedFile,
  }) async {
    if (_isUploadingMaterial) return false;
    if (kind == MaterialKind.pastedText) {
      _uploadError = 'Choose a PDF or image to upload.';
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
      _uploadError = 'Log in to upload materials.';
      notifyListeners();
      return false;
    }

    _isUploadingMaterial = true;
    _uploadProgress = null;
    _uploadStage = 'Reading file';
    _uploadError = null;
    notifyListeners();
    try {
      final request = await prepareMaterialUpload(
        selectedFile: selectedFile,
        expectedKind: kind,
        materialId: materialIdGenerator(),
        subjectId: subjectId,
      );
      _uploadStage = 'Uploading file';
      notifyListeners();
      final material = await materialUploadRepository.uploadMaterial(
        expectedUser: effectiveUser,
        request: request,
        onProgress: (progress) {
          _uploadProgress = progress;
          _uploadStage = progress == 1 ? 'Saving material' : 'Uploading file';
          notifyListeners();
        },
      );
      _materials = [
        material,
        for (final existing in _materials)
          if (existing.id != material.id) existing,
      ];
      return true;
    } catch (error) {
      _uploadError = _materialUploadMessageFor(error);
      return false;
    } finally {
      _isUploadingMaterial = false;
      _uploadProgress = null;
      _uploadStage = null;
      notifyListeners();
    }
  }

  Future<bool> extractPdfTextFor(
    AuthUser? user,
    String materialId, {
    MaterialQueueWorkGuard? queueGuard,
  }) async {
    if (!_isCurrentQueueWork(queueGuard)) return false;
    if (_extractingPdfIds.contains(materialId)) return false;
    final material = materialById(materialId);
    if (material == null ||
        material.kind != MaterialKind.pdf ||
        material.sourceKind != MaterialSourceKind.upload ||
        material.processingStatus == MaterialProcessingStatus.processing ||
        (material.processingStatus == MaterialProcessingStatus.ready &&
            material.hasContentText)) {
      if (_isCurrentQueueWork(queueGuard)) {
        _pdfExtractionErrors[materialId] = 'This PDF cannot be extracted.';
        notifyListeners();
      }
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
      if (_isCurrentQueueWork(queueGuard)) {
        _pdfExtractionErrors[materialId] = 'Log in to extract PDF text.';
        notifyListeners();
      }
      return false;
    }

    if (!_isCurrentQueueWork(queueGuard)) return false;
    _extractingPdfIds.add(materialId);
    _pdfExtractionErrors.remove(materialId);
    notifyListeners();
    try {
      final result = await pdfTextExtractionRepository.extractPdfText(
        user: effectiveUser,
        materialId: materialId,
      );
      if (!_isCurrentQueueWork(queueGuard)) return false;
      final returnedMaterial =
          config.effectiveBackendMode == AppBackendMode.supabase
          ? result.material
          : result.material.copyWith(
              subjectId: material.subjectId,
              title: material.title,
              createdLabel: material.createdLabel,
              storageBucket: material.storageBucket,
              storagePath: material.storagePath,
              mimeType: material.mimeType,
              fileSizeBytes: material.fileSizeBytes,
            );
      _replaceMaterial(returnedMaterial);
      if (result.errorMessage != null) {
        _pdfExtractionErrors[materialId] = result.errorMessage!;
      }
      return result.succeeded;
    } catch (error) {
      if (!_isCurrentQueueWork(queueGuard)) return false;
      _pdfExtractionErrors[materialId] = error is PdfTextExtractionException
          ? error.message
          : 'Could not extract text. Try again.';
      return false;
    } finally {
      if (_isCurrentQueueSession(queueGuard)) {
        _extractingPdfIds.remove(materialId);
        notifyListeners();
      }
    }
  }

  Future<bool> scanPdfWithOcrFor(AuthUser? user, String materialId) async {
    if (_scanningPdfIds.contains(materialId)) return false;
    final material = materialById(materialId);
    if (material == null ||
        !isScannedPdfOcrAvailable(material) ||
        (material.pdfExtraction?.pageCount ?? 0) > 10) {
      _scannedPdfOcrErrors[materialId] = 'This PDF cannot be scanned with OCR.';
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
      _scannedPdfOcrErrors[materialId] = 'Log in to scan this PDF.';
      notifyListeners();
      return false;
    }
    _scanningPdfIds.add(materialId);
    _scannedPdfOcrErrors.remove(materialId);
    notifyListeners();
    try {
      final result = await scannedPdfOcrRepository.scan(
        user: effectiveUser,
        materialId: materialId,
      );
      final returned = config.effectiveBackendMode == AppBackendMode.supabase
          ? result.material
          : result.material.copyWith(
              subjectId: material.subjectId,
              title: material.title,
              createdLabel: material.createdLabel,
              storageBucket: material.storageBucket,
              storagePath: material.storagePath,
              mimeType: material.mimeType,
              fileSizeBytes: material.fileSizeBytes,
            );
      _replaceMaterial(returned);
      if (result.errorMessage != null) {
        _scannedPdfOcrErrors[materialId] = result.errorMessage!;
      }
      return result.succeeded;
    } catch (error) {
      _scannedPdfOcrErrors[materialId] = error is ScannedPdfOcrException
          ? error.message
          : 'Could not scan this PDF. Try again.';
      return false;
    } finally {
      _scanningPdfIds.remove(materialId);
      notifyListeners();
    }
  }

  Future<bool> extractImageTextFor(
    AuthUser? user,
    String materialId, {
    MaterialQueueWorkGuard? queueGuard,
  }) async {
    if (!_isCurrentQueueWork(queueGuard)) return false;
    if (_extractingImageIds.contains(materialId)) return false;
    final material = materialById(materialId);
    if (material == null ||
        material.kind != MaterialKind.image ||
        material.sourceKind != MaterialSourceKind.upload ||
        material.processingStatus == MaterialProcessingStatus.processing ||
        (material.processingStatus == MaterialProcessingStatus.ready &&
            material.hasContentText)) {
      if (_isCurrentQueueWork(queueGuard)) {
        _imageExtractionErrors[materialId] = 'This image cannot be processed.';
        notifyListeners();
      }
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
      if (_isCurrentQueueWork(queueGuard)) {
        _imageExtractionErrors[materialId] = 'Log in to extract image text.';
        notifyListeners();
      }
      return false;
    }
    if (!_isCurrentQueueWork(queueGuard)) return false;
    _extractingImageIds.add(materialId);
    _imageExtractionErrors.remove(materialId);
    notifyListeners();
    try {
      final result = await imageTextExtractionRepository.extractImageText(
        user: effectiveUser,
        materialId: materialId,
      );
      if (!_isCurrentQueueWork(queueGuard)) return false;
      final returned = config.effectiveBackendMode == AppBackendMode.supabase
          ? result.material
          : result.material.copyWith(
              subjectId: material.subjectId,
              title: material.title,
              createdLabel: material.createdLabel,
              storageBucket: material.storageBucket,
              storagePath: material.storagePath,
              mimeType: material.mimeType,
              fileSizeBytes: material.fileSizeBytes,
            );
      _replaceMaterial(returned);
      if (result.errorMessage != null) {
        _imageExtractionErrors[materialId] = result.errorMessage!;
      }
      return result.succeeded;
    } catch (error) {
      if (!_isCurrentQueueWork(queueGuard)) return false;
      _imageExtractionErrors[materialId] = error is ImageTextExtractionException
          ? error.message
          : 'Could not extract image text. Try again.';
      return false;
    } finally {
      if (_isCurrentQueueSession(queueGuard)) {
        _extractingImageIds.remove(materialId);
        notifyListeners();
      }
    }
  }

  void _replaceMaterial(StudyMaterial material) {
    if (_deletingMaterialIds.contains(material.id) ||
        materialById(material.id) == null) {
      return;
    }
    _materials = [
      for (final existing in _materials)
        if (existing.id == material.id) material else existing,
    ];
    materialUploadQueue.acceptAuthoritativeMaterial(material);
  }

  void _upsertQueuedMaterial(StudyMaterial material) {
    if (_deletingMaterialIds.contains(material.id)) return;
    _materials = [
      material,
      for (final existing in _materials)
        if (existing.id != material.id) existing,
    ];
    materialUploadQueue.acceptAuthoritativeMaterial(material);
    notifyListeners();
  }

  Future<MaterialQueueProcessingResult> _processQueuedMaterial(
    AuthUser user,
    StudyMaterial material,
    MaterialQueueWorkGuard queueGuard,
  ) async {
    if (!queueGuard.isCurrent) {
      return MaterialQueueProcessingResult(
        material: material,
        succeeded: false,
      );
    }
    if (config.effectiveBackendMode != AppBackendMode.supabase ||
        materialAnalysisRepository is EmptyMaterialAnalysisRepository) {
      final succeeded = material.kind == MaterialKind.pdf
          ? await extractPdfTextFor(user, material.id, queueGuard: queueGuard)
          : await extractImageTextFor(
              user,
              material.id,
              queueGuard: queueGuard,
            );
      final authoritative = materialById(material.id) ?? material;
      return MaterialQueueProcessingResult(
        material: authoritative,
        succeeded:
            succeeded &&
            authoritative.processingStatus == MaterialProcessingStatus.ready &&
            authoritative.hasContentText,
      );
    }
    _bindAnalysis(user);
    final actionGuard = _beginAnalysisAction(
      material.id,
      AnalysisExplicitAction.preflight,
    );
    if (actionGuard == null) {
      return MaterialQueueProcessingResult(material: material, succeeded: true);
    }
    final generation = _nextAnalysis(material.id);
    try {
      final status = await materialAnalysisRepository.prepare(
        user: user,
        materialId: material.id,
        mode: queueGuard.analysisMode,
        confirmLargeDocument: false,
      );
      if (!queueGuard.isCurrent ||
          !_currentAnalysis(user, material.id, generation)) {
        return MaterialQueueProcessingResult(
          material: material,
          succeeded: false,
        );
      }
      _publishAnalysisStatus(material.id, status, allowRestart: true);
      _analysisErrors.remove(material.id);
      notifyListeners();
      _scheduleAnalysis(user, material.id);
      return MaterialQueueProcessingResult(material: material, succeeded: true);
    } on MaterialAnalysisException catch (e) {
      if (_currentAnalysis(user, material.id, generation)) {
        _analysisErrors[material.id] = e.code;
        notifyListeners();
      }
      if (e.code == AnalysisErrorCode.documentTooLarge) {
        return MaterialQueueProcessingResult(
          material: material,
          succeeded: true,
        );
      }
      return MaterialQueueProcessingResult(
        material: material,
        succeeded: false,
      );
    } finally {
      _endAnalysisAction(actionGuard);
    }
  }

  Future<bool> deleteSubjectFor(AuthUser? user, String subjectId) async {
    if (_deletingSubjectIds.contains(subjectId)) return false;
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _subjectDeletionErrors[subjectId] = DeletionSafeCode.unauthorized;
      notifyListeners();
      return false;
    }
    final effectiveUser =
        user ??
        const AuthUser(id: 'mock-user', email: 'alex.student@example.test');
    _deletingSubjectIds.add(subjectId);
    _subjectDeletionErrors.remove(subjectId);
    notifyListeners();
    try {
      final result = await subjectDeletionRepository.deleteSubject(
        user: effectiveUser,
        subjectId: subjectId,
      );
      if (!result.completed) {
        _subjectDeletionErrors[subjectId] =
            result.code ?? DeletionSafeCode.unknown;
        return false;
      }
      final materialIds = _materials
          .where((item) => item.subjectId == subjectId)
          .map((item) => item.id)
          .toSet();
      final activeSessionRemoved = _studySessions.any(
        (item) => item.subjectId == subjectId,
      );
      _subjects.removeWhere((item) => item.id == subjectId);
      _materials.removeWhere((item) => item.subjectId == subjectId);
      _flashcards.removeWhere(
        (item) =>
            item.subjectId == subjectId ||
            materialIds.contains(item.materialId),
      );
      _quizzes.removeWhere(
        (item) =>
            item.subjectId == subjectId ||
            materialIds.contains(item.materialId),
      );
      _quizAttempts.removeWhere((item) => item.subjectId == subjectId);
      _studySessions.removeWhere(
        (item) =>
            item.subjectId == subjectId ||
            materialIds.contains(item.materialId),
      );
      final userId = _materialWorkSessionUserId;
      if (activeSessionRemoved && userId != null) {
        _queueStudySessionPersistence(
          () => preferencesStore.clearActiveStudySession(userId),
        );
      }
      _cumulativeWeakTopics.removeWhere((item) => item.subjectId == subjectId);
      _favoriteMaterialIds.removeAll(materialIds);
      if (_latestQuizCompletion?.subjectId == subjectId) {
        _latestQuizCompletion = null;
      }
      for (final id in materialIds) {
        _materialLifecycleErrors.remove(id);
        _pdfExtractionErrors.remove(id);
        _scannedPdfOcrErrors.remove(id);
        _imageExtractionErrors.remove(id);
        _staleMaterialProcessors.remove(id);
      }
      await loadStudyProgressFor(user);
      return true;
    } on DeletionException catch (error) {
      _subjectDeletionErrors[subjectId] = error.code;
      return false;
    } catch (_) {
      _subjectDeletionErrors[subjectId] = DeletionSafeCode.unknown;
      return false;
    } finally {
      _deletingSubjectIds.remove(subjectId);
      notifyListeners();
    }
  }

  Future<bool> deleteMaterialFor(AuthUser? user, String materialId) async {
    if (_deletingMaterialIds.contains(materialId)) return false;
    final material = materialById(materialId);
    if (material == null) return true;
    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        user == null) {
      _materialLifecycleErrors[materialId] = 'Log in to delete this material.';
      notifyListeners();
      return false;
    }
    _deletingMaterialIds.add(materialId);
    _materialLifecycleErrors.remove(materialId);
    notifyListeners();
    try {
      await materialLifecycleRepository.deleteMaterial(
        user: effectiveUser,
        materialId: materialId,
      );
      _removeMaterialLocally(materialId);
      await loadStudyProgressFor(user);
      return true;
    } catch (error) {
      final exists = await materialLifecycleRepository.materialExists(
        user: effectiveUser,
        materialId: materialId,
      );
      if (exists == false) {
        _removeMaterialLocally(materialId);
        await loadStudyProgressFor(user);
        return true;
      }
      _materialLifecycleErrors[materialId] = error is MaterialLifecycleException
          ? error.message
          : 'Could not delete the material. Try again.';
      return false;
    } finally {
      _deletingMaterialIds.remove(materialId);
      notifyListeners();
    }
  }

  void _removeMaterialLocally(String materialId) {
    stopObservingMaterialAnalysis(materialId);
    materialUploadQueue.removeAuthoritativeMaterial(materialId);
    _materials = [
      for (final item in _materials)
        if (item.id != materialId) item,
    ];
    _favoriteMaterialIds.remove(materialId);
    _flashcards = [
      for (final item in _flashcards)
        if (item.materialId != materialId) item,
    ];
    _quizzes = [
      for (final item in _quizzes)
        if (item.materialId != materialId) item,
    ];
    final activeSessionRemoved = _studySessions.any(
      (session) => session.materialId == materialId,
    );
    for (var index = 0; index < _studySessions.length; index++) {
      if (_studySessions[index].materialId == materialId) {
        _studySessions[index] = _studySessions[index].detachMaterial();
      }
    }
    final userId = _materialWorkSessionUserId;
    if (activeSessionRemoved && userId != null) {
      _queueStudySessionPersistence(
        () => preferencesStore.clearActiveStudySession(userId),
      );
    }
    _pdfExtractionErrors.remove(materialId);
    _scannedPdfOcrErrors.remove(materialId);
    _imageExtractionErrors.remove(materialId);
    _staleMaterialProcessors.remove(materialId);
    _materialLifecycleErrors.remove(materialId);
    _analysisStatuses.remove(materialId);
    _analysisErrors.remove(materialId);
    _analysisPending.remove(materialId);
    _analysisObservations.remove(materialId);
    _analysisActions.remove(materialId);
  }

  Future<void> inspectMaterialRecoveryFor(
    AuthUser? user,
    String materialId,
  ) async {
    if (materialById(materialId)?.processingStatus !=
        MaterialProcessingStatus.processing) {
      _staleMaterialProcessors.remove(materialId);
      return;
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
      return;
    }
    final result = await materialLifecycleRepository.inspectRecovery(
      user: effectiveUser,
      materialId: materialId,
    );
    if (result.eligible && result.processor != null) {
      _staleMaterialProcessors[materialId] = result.processor!;
    } else {
      _staleMaterialProcessors.remove(materialId);
    }
    notifyListeners();
  }

  Future<bool> recoverStuckMaterialFor(
    AuthUser? user,
    String materialId,
  ) async {
    final processor = _staleMaterialProcessors[materialId];
    if (processor == null) return false;
    final effectiveUser =
        user ??
        const AuthUser(
          id: 'mock-user',
          email: 'alex.student@example.test',
          displayName: 'Alex Student',
        );
    try {
      await materialLifecycleRepository.recover(
        user: effectiveUser,
        materialId: materialId,
        processor: processor,
      );
      _staleMaterialProcessors.remove(materialId);
      await loadMaterialsFor(user);
      return true;
    } catch (error) {
      _materialLifecycleErrors[materialId] = error is MaterialLifecycleException
          ? error.message
          : 'Processing could not be reset.';
      notifyListeners();
      return false;
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
      final flashcardFavorites =
          favoriteRepository is FlashcardFavoriteRepository
          ? (favoriteRepository as FlashcardFavoriteRepository)
                .loadFlashcardFavoriteIds(user)
          : Future<Set<String>>.value(const {});
      final favoriteResults = await Future.wait([
        favoriteRepository.loadMaterialFavoriteIds(user),
        flashcardFavorites,
      ]);
      final favoriteIds = favoriteResults[0];
      _favoriteMaterialIds
        ..clear()
        ..addAll(favoriteIds);
      _favoriteFlashcardIds
        ..clear()
        ..addAll(favoriteResults[1]);
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
      _flashcards = [
        for (final card in await flashcardRepository.loadFlashcards(user))
          card.copyWith(isFavorite: _favoriteFlashcardIds.contains(card.id)),
      ];
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

  Future<void> loadCumulativeWeakTopicsFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _cumulativeWeakTopics = _deriveCumulativeWeakTopics(_quizAttempts);
      _weakTopicSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    if (user == null) {
      _cumulativeWeakTopics = [];
      _weakTopicSyncErrorMessage = null;
      notifyListeners();
      return;
    }

    _isLoadingCumulativeWeakTopics = true;
    _weakTopicSyncErrorMessage = null;
    notifyListeners();
    try {
      _cumulativeWeakTopics = await weakTopicRepository.loadWeakTopics(user);
    } catch (error) {
      _weakTopicSyncErrorMessage = _weakTopicMessageFor(error);
    } finally {
      _isLoadingCumulativeWeakTopics = false;
      notifyListeners();
    }
  }

  StudyProgress? get studyProgress => _studyProgress;
  bool get isLoadingStudyProgress => _isLoadingStudyProgress;
  String? get studyProgressErrorMessage => _studyProgressErrorMessage;

  Future<void> loadStudyProgressFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      _studyProgress = null;
      _studyProgressErrorMessage = null;
      notifyListeners();
      return;
    }
    if (user == null) {
      _studyProgress = null;
      _studyProgressErrorMessage = null;
      notifyListeners();
      return;
    }
    _isLoadingStudyProgress = true;
    _studyProgressErrorMessage = null;
    notifyListeners();
    try {
      _studyProgress = await studyProgressRepository.loadProgress(user);
    } catch (error) {
      _studyProgressErrorMessage = error is StudyProgressRepositoryException
          ? error.message
          : 'Could not load authoritative study progress.';
    } finally {
      _isLoadingStudyProgress = false;
      notifyListeners();
    }
  }

  void clearSyncedSubjectsForSignOut() {
    final signedOutUserId = _materialWorkSessionUserId;
    if (signedOutUserId != null) {
      _queueStudySessionPersistence(
        () => preferencesStore.clearActiveStudySession(signedOutUserId),
      );
    }
    _materialWorkSessionUserId = null;
    _studySessions.clear();
    _sessionCounter = 0;
    materialUploadQueue.clearForSessionChange();
    _clearMaterialWorkState();
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      notifyListeners();
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
    _weakTopicSyncErrorMessage = null;
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
    _isLoadingCumulativeWeakTopics = false;
    _extractingPdfIds.clear();
    _pdfExtractionErrors.clear();
    _scanningPdfIds.clear();
    _scannedPdfOcrErrors.clear();
    _extractingImageIds.clear();
    _imageExtractionErrors.clear();
    _deletingMaterialIds.clear();
    _deletingSubjectIds.clear();
    _subjectDeletionErrors.clear();
    _materialLifecycleErrors.clear();
    _staleMaterialProcessors.clear();
    _favoriteMaterialIds.clear();
    _flashcards = [];
    _quizzes = [];
    _quizAttempts = [];
    _cumulativeWeakTopics = [];
    _studyProgress = null;
    _isLoadingStudyProgress = false;
    _studyProgressErrorMessage = null;
    _activeStudyActivities = [];
    _completedStudyActivities = [];
    _studyActivityErrorMessage = null;
    _latestQuizCompletion = null;
    notifyListeners();
  }

  bool _isCurrentQueueWork(MaterialQueueWorkGuard? guard) =>
      guard == null || guard.isCurrent;

  bool _isCurrentQueueSession(MaterialQueueWorkGuard? guard) =>
      guard == null || guard.isSessionCurrent;

  void _clearMaterialWorkState() {
    _extractingPdfIds.clear();
    _pdfExtractionErrors.clear();
    _extractingImageIds.clear();
    _imageExtractionErrors.clear();
    _staleMaterialProcessors.clear();
    _analysisUserId = null;
    _analysisUser = null;
    _analysisStatuses.clear();
    _analysisErrors.clear();
    for (final id in _analysisGenerations.keys.toList()) {
      _nextAnalysis(id);
    }
    _analysisLoops.clear();
    _analysisAdvanceTasks.clear();
    _analysisPending.clear();
    _analysisObservations.clear();
    _analysisForcedObservations.clear();
    _analysisReconciling.clear();
    _analysisStopped.clear();
    _analysisRetryGuards.clear();
    _analysisActions.clear();
    _analysisResumeOperation = null;
  }

  void clearSyncedWorkspaceForSignOut() {
    clearSyncedSubjectsForSignOut();
  }

  Future<void> loadPreferences() async {
    AppLanguagePreference loadedPreference;
    try {
      loadedPreference = AppLanguagePreferenceX.fromPersistedCode(
        await preferencesStore.loadLocaleCode(),
      );
    } catch (_) {
      loadedPreference = AppLanguagePreference.system;
    }
    AppAppearancePreference loadedAppearance;
    try {
      loadedAppearance = AppAppearancePreferenceX.fromPersistedCode(
        await preferencesStore.loadAppearanceCode(),
      );
    } catch (_) {
      loadedAppearance = AppAppearancePreference.system;
    }
    if (_languagePreference == loadedPreference &&
        _appearancePreference == loadedAppearance) {
      return;
    }
    _languagePreference = loadedPreference;
    _appearancePreference = loadedAppearance;
    notifyListeners();
  }

  void setLanguagePreference(AppLanguagePreference value) {
    if (_languagePreference == value) {
      return;
    }
    _languagePreference = value;
    notifyListeners();
    preferencesStore.saveLocaleCode(value.persistedCode).ignore();
  }

  void setAppearancePreference(AppAppearancePreference value) {
    if (_appearancePreference == value) return;
    _appearancePreference = value;
    notifyListeners();
    preferencesStore.saveAppearanceCode(value.persistedCode).ignore();
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
    final result = _materials
        .where((material) => material.subjectId == subjectId)
        .toList();
    result.sort(_compareSubjectMaterials);
    return result;
  }

  int _compareSubjectMaterials(StudyMaterial left, StudyMaterial right) {
    final favoriteOrder =
        (_favoriteMaterialIds.contains(right.id) ? 1 : 0) -
        (_favoriteMaterialIds.contains(left.id) ? 1 : 0);
    if (favoriteOrder != 0) return favoriteOrder;
    final leftCreated = left.createdAt;
    final rightCreated = right.createdAt;
    if (leftCreated != null && rightCreated != null) {
      final dateOrder = rightCreated.compareTo(leftCreated);
      if (dateOrder != 0) return dateOrder;
    } else if (leftCreated != null) {
      return -1;
    } else if (rightCreated != null) {
      return 1;
    }
    return left.id.compareTo(right.id);
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

  Quiz? quizById(String quizId) =>
      _quizzes.where((quiz) => quiz.id == quizId).firstOrNull;
  QuizAttempt? quizAttemptById(String attemptId) =>
      _quizAttempts.where((attempt) => attempt.id == attemptId).firstOrNull;
  QuizAttempt? latestQuizAttemptForMaterial(String materialId) {
    final quizIds = _quizzes
        .where((quiz) => quiz.materialId == materialId)
        .map((quiz) => quiz.id)
        .toSet();
    return _quizAttempts
        .where((attempt) => quizIds.contains(attempt.quizId))
        .firstOrNull;
  }

  List<Flashcard> get favoriteFlashcards {
    if (config.effectiveBackendMode == AppBackendMode.supabase) {
      return _flashcards
          .where((card) => _favoriteFlashcardIds.contains(card.id))
          .map((card) => card.copyWith(isFavorite: true))
          .toList();
    }
    return _flashcards.where((flashcard) => flashcard.isFavorite).toList();
  }

  bool isMaterialFavorite(String materialId) {
    return _favoriteMaterialIds.contains(materialId);
  }

  bool canGenerateSummaryForMaterial(StudyMaterial material) {
    return isAiSourceReadyForMaterial(material) &&
        material.content.trim().length >= summaryMinimumContentCharacters;
  }

  bool canGenerateFlashcardsForMaterial(StudyMaterial material) {
    final status = _analysisStatuses[material.id];
    final hasValidatedSummary =
        status != null &&
        status.summarySchemaVersion ==
            supportedStructuredSummarySchemaVersion &&
        status.summary != null &&
        {
          AnalysisState.completed,
          AnalysisState.completedWithWarnings,
        }.contains(status.state);
    return hasValidatedSummary ||
        (isAiSourceReadyForMaterial(material) &&
            material.content.trim().length >= summaryMinimumContentCharacters);
  }

  bool canGenerateQuizForMaterial(StudyMaterial material) {
    final status = _analysisStatuses[material.id];
    final hasValidatedSummary =
        status != null &&
        status.summarySchemaVersion ==
            supportedStructuredSummarySchemaVersion &&
        status.summary != null &&
        {
          AnalysisState.completed,
          AnalysisState.completedWithWarnings,
        }.contains(status.state);
    return hasValidatedSummary ||
        (isAiSourceReadyForMaterial(material) &&
            material.content.trim().length >= summaryMinimumContentCharacters);
  }

  List<PersistedStudyActivity> get activeStudyActivities =>
      List.unmodifiable(_activeStudyActivities);

  List<PersistedStudyActivity> get completedStudyActivities =>
      List.unmodifiable(_completedStudyActivities);

  PersistedStudyActivity? get latestActiveStudyActivity =>
      _activeStudyActivities.firstOrNull;

  String? get studyActivityErrorMessage => _studyActivityErrorMessage;

  Future<void> loadStudyActivitiesFor(AuthUser? user) async {
    if (config.effectiveBackendMode != AppBackendMode.supabase ||
        user == null) {
      _activeStudyActivities = [];
      _completedStudyActivities = [];
      _studyActivityErrorMessage = null;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait([
        studyActivityRepository.loadActive(user),
        studyActivityRepository.loadRecentCompleted(user),
      ]);
      _activeStudyActivities = results[0];
      _completedStudyActivities = results[1];
      _studyActivityErrorMessage = null;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not restore study sessions.';
    }
    notifyListeners();
  }

  Future<PersistedStudyActivity?> startFlashcardActivity({
    required AuthUser? user,
    required StudyMaterial material,
    required List<Flashcard> cards,
    FlashcardTrainingMode mode = FlashcardTrainingMode.all,
  }) async {
    if (user == null ||
        cards.isEmpty ||
        cards.any(
          (card) =>
              card.materialId != material.id ||
              card.subjectId != material.subjectId,
        )) {
      _studyActivityErrorMessage = 'Could not start flashcard training.';
      notifyListeners();
      return null;
    }
    try {
      final session = await studyActivityRepository.startFlashcards(
        user: user,
        sessionId: newUuidV4(),
        materialId: material.id,
        mode: mode,
        cardIds: cards.map((card) => card.id).toList(),
      );
      _upsertActiveStudyActivity(session);
      return session;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not start flashcard training.';
      notifyListeners();
      return null;
    }
  }

  Future<PersistedStudyActivity?> updateFlashcardActivity({
    required AuthUser? user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required bool answerVisible,
    String? cardId,
    FlashcardReviewResult? result,
  }) async {
    if (user == null) return null;
    try {
      final updated = await studyActivityRepository.updateFlashcards(
        user: user,
        session: session,
        currentIndex: currentIndex,
        answerVisible: answerVisible,
        cardId: cardId,
        result: result == null
            ? null
            : result == FlashcardReviewResult.known
            ? 'known'
            : 'not_known',
        reviewedAt: result == null ? null : DateTime.now().toUtc(),
      );
      _upsertActiveStudyActivity(updated);
      if (result != null) {
        await loadFlashcardsFor(user);
        await loadStudyProgressFor(user);
      }
      return updated;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not save review progress.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> finalizeFlashcardActivity(
    AuthUser? user,
    String sessionId,
  ) async {
    if (user == null) return false;
    try {
      await studyActivityRepository.finalizeFlashcards(
        user: user,
        sessionId: sessionId,
      );
      await loadStudyActivitiesFor(user);
      await loadStudyProgressFor(user);
      return true;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not complete flashcard training.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelEmptyStudyActivity(
    AuthUser? user,
    PersistedStudyActivity session,
  ) async {
    if (user == null ||
        session.type != PersistedStudyActivityType.flashcards ||
        session.flashcardMode != FlashcardTrainingMode.all ||
        session.currentIndex != 0 ||
        session.knownCount != 0 ||
        session.notKnownCount != 0 ||
        session.isCompleted) {
      _studyActivityErrorMessage =
          'Only an empty active session can be cancelled.';
      notifyListeners();
      return false;
    }
    try {
      await studyActivityRepository.cancelEmptySession(
        user: user,
        sessionId: session.id,
      );
      _activeStudyActivities.removeWhere((item) => item.id == session.id);
      _studyActivityErrorMessage = null;
      await loadStudyProgressFor(user);
      notifyListeners();
      return true;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not cancel the empty study session.';
      notifyListeners();
      return false;
    }
  }

  Future<PersistedStudyActivity?> startQuizActivity({
    required AuthUser? user,
    required Quiz quiz,
  }) async {
    if (user == null) return null;
    try {
      final session = await studyActivityRepository.startQuiz(
        user: user,
        attemptId: newUuidV4(),
        quiz: quiz,
      );
      _upsertActiveStudyActivity(session);
      return session;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not start quiz.';
      notifyListeners();
      return null;
    }
  }

  Future<PersistedStudyActivity?> updateQuizActivity({
    required AuthUser? user,
    required PersistedStudyActivity session,
    required int currentIndex,
    required String questionId,
    required String answer,
  }) async {
    if (user == null) return null;
    try {
      final updated = await studyActivityRepository.updateQuiz(
        user: user,
        session: session,
        currentIndex: currentIndex,
        questionId: questionId,
        selectedAnswer: answer,
      );
      _upsertActiveStudyActivity(updated);
      return updated;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not save quiz progress.';
      notifyListeners();
      return null;
    }
  }

  Future<PersistedStudyActivity?> advanceQuizActivity({
    required AuthUser? user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async {
    if (user == null) return null;
    try {
      final updated = await studyActivityRepository.advanceQuiz(
        user: user,
        session: session,
        currentIndex: currentIndex,
      );
      _upsertActiveStudyActivity(updated);
      return updated;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not save quiz progress.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> finalizeQuizActivity(AuthUser? user, String attemptId) async {
    if (user == null) return false;
    try {
      await studyActivityRepository.finalizeQuiz(
        user: user,
        attemptId: attemptId,
      );
      await loadStudyActivitiesFor(user);
      await loadQuizAttemptsFor(user);
      await loadCumulativeWeakTopicsFor(user);
      await loadStudyProgressFor(user);
      return true;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not complete quiz.';
      notifyListeners();
      return false;
    }
  }

  Future<PersistedStudyActivity?> startMistakeReviewActivity(
    AuthUser? user,
    String attemptId,
  ) async {
    if (user == null) return null;
    try {
      final session = await studyActivityRepository.startMistakeReview(
        user: user,
        attemptId: attemptId,
      );
      _upsertActiveStudyActivity(session);
      return session;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'No saved mistakes are available.';
      notifyListeners();
      return null;
    }
  }

  Future<PersistedStudyActivity?> updateMistakeReviewActivity({
    required AuthUser? user,
    required PersistedStudyActivity session,
    required int currentIndex,
  }) async {
    if (user == null) return null;
    try {
      final updated = await studyActivityRepository.updateMistakeReview(
        user: user,
        session: session,
        currentIndex: currentIndex,
      );
      if (updated.isCompleted) {
        await loadStudyActivitiesFor(user);
        await loadStudyProgressFor(user);
      } else {
        _upsertActiveStudyActivity(updated);
      }
      return updated;
    } catch (error) {
      _studyActivityErrorMessage = error is StudyActivityRepositoryException
          ? error.message
          : 'Could not save mistake review.';
      notifyListeners();
      return null;
    }
  }

  void _upsertActiveStudyActivity(PersistedStudyActivity session) {
    _activeStudyActivities = [
      session,
      for (final existing in _activeStudyActivities)
        if (existing.id != session.id) existing,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _studyActivityErrorMessage = null;
    notifyListeners();
  }

  bool isAiSourceReadyForMaterial(StudyMaterial material) {
    final status = _analysisStatuses[material.id];
    final hasValidatedSummary =
        status != null &&
        status.summarySchemaVersion ==
            supportedStructuredSummarySchemaVersion &&
        status.summary != null &&
        {
          AnalysisState.completed,
          AnalysisState.completedWithWarnings,
        }.contains(status.state);
    return hasValidatedSummary ||
        (material.kind == MaterialKind.pastedText &&
            material.sourceKind == MaterialSourceKind.manual) ||
        (material.kind == MaterialKind.pdf &&
            material.sourceKind == MaterialSourceKind.upload &&
            material.processingStatus == MaterialProcessingStatus.ready &&
            material.hasContentText) ||
        (material.kind == MaterialKind.image &&
            material.sourceKind == MaterialSourceKind.upload &&
            material.processingStatus == MaterialProcessingStatus.ready &&
            material.hasContentText);
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

  Future<bool> toggleFlashcardFavoriteFor(AuthUser? user, String cardId) async {
    final card = _flashcardById(cardId);
    if (card == null) {
      _favoriteSyncErrorMessage = 'Flashcard unavailable.';
      notifyListeners();
      return false;
    }
    if (config.effectiveBackendMode != AppBackendMode.supabase) {
      toggleFavorite(cardId);
      return true;
    }
    if (user == null) {
      _favoriteSyncErrorMessage = 'Log in to sync favorites.';
      notifyListeners();
      return false;
    }
    final favorite = _favoriteFlashcardIds.contains(cardId);
    try {
      if (favorite) {
        final repository = favoriteRepository;
        if (repository is! FlashcardFavoriteRepository) {
          throw const FavoriteRepositoryException(
            'Favorite sync is not configured.',
          );
        }
        await (repository as FlashcardFavoriteRepository)
            .removeFlashcardFavorite(user: user, flashcardId: cardId);
        _favoriteFlashcardIds.remove(cardId);
      } else {
        final repository = favoriteRepository;
        if (repository is! FlashcardFavoriteRepository) {
          throw const FavoriteRepositoryException(
            'Favorite sync is not configured.',
          );
        }
        await (repository as FlashcardFavoriteRepository).addFlashcardFavorite(
          user: user,
          flashcardId: cardId,
        );
        _favoriteFlashcardIds.add(cardId);
      }
      _flashcards = [
        for (final item in _flashcards)
          item.id == cardId ? item.copyWith(isFavorite: !favorite) : item,
      ];
      _favoriteSyncErrorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _favoriteSyncErrorMessage = _favoriteUpdateMessageFor(error);
      notifyListeners();
      return false;
    }
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
    if (config.effectiveBackendMode == AppBackendMode.supabase &&
        material.sourceKind == MaterialSourceKind.upload) {
      _summaryGenerationErrorMessage = 'Could not generate summary. Try again.';
      notifyListeners();
      return false;
    }
    if (!isAiSourceReadyForMaterial(material)) {
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
      if (_deletingMaterialIds.contains(materialId) ||
          materialById(materialId) == null) {
        return false;
      }
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

  Future<FlashcardGenerationResult?> generateFlashcardsFor(
    AuthUser? user,
    String materialId, {
    required int requestedNewCount,
  }) async {
    if (_isGeneratingFlashcards) {
      return null;
    }
    if (requestedNewCount < 1 || requestedNewCount > 30) {
      _flashcardGenerationErrorMessage =
          'Choose between 1 and 30 new flashcards.';
      notifyListeners();
      return null;
    }
    final material = materialById(materialId);
    if (material == null) {
      _flashcardGenerationErrorMessage = 'Material unavailable.';
      notifyListeners();
      return null;
    }
    if (!isAiSourceReadyForMaterial(material)) {
      _flashcardGenerationErrorMessage =
          'Could not generate flashcards. Try again.';
      notifyListeners();
      return null;
    }
    if (!canGenerateFlashcardsForMaterial(material)) {
      _flashcardGenerationErrorMessage = flashcardsTooShortMessage;
      notifyListeners();
      return null;
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
      return null;
    }

    _isGeneratingFlashcards = true;
    _flashcardGenerationErrorMessage = null;
    notifyListeners();
    try {
      final generation = await flashcardRepository.generateFlashcards(
        user: effectiveUser,
        materialId: material.id,
        requestedNewCount: requestedNewCount,
      );
      if (_deletingMaterialIds.contains(materialId) ||
          materialById(materialId) == null) {
        return null;
      }
      if (generation.requestedCount != requestedNewCount ||
          generation.createdCount != generation.newFlashcards.length ||
          generation.createdCount < 0 ||
          generation.createdCount > requestedNewCount) {
        throw const FlashcardRepositoryException(
          'Could not generate flashcards. Try again.',
        );
      }
      final existingIds = _flashcards.map((card) => card.id).toSet();
      final newIds = <String>{};
      final newCards = [
        for (final card in generation.newFlashcards)
          if (!existingIds.contains(card.id) && newIds.add(card.id))
            card.copyWith(
              subjectId: material.subjectId,
              materialId: material.id,
            ),
      ];
      _flashcards = [..._flashcards, ...newCards];
      return FlashcardGenerationResult(
        requestedCount: generation.requestedCount,
        createdCount: newCards.length,
        newFlashcards: newCards,
      );
    } catch (error) {
      _flashcardGenerationErrorMessage = _flashcardGenerateMessageFor(error);
      return null;
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
    if (!isAiSourceReadyForMaterial(material)) {
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
      if (_deletingMaterialIds.contains(materialId) ||
          materialById(materialId) == null) {
        return false;
      }
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
    required String attemptId,
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
          isCorrect:
              (selectedAnswers[question.id] ?? '').isNotEmpty &&
              selectedAnswers[question.id] == question.correctAnswer,
          topic: question.topic.trim(),
          difficulty: question.difficulty,
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
      id: attemptId,
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
        submission: QuizAttemptSubmission(
          attemptId: attemptId,
          quizId: quiz.id,
          startedAt: startedAt.toUtc(),
          selectedAnswers: [
            for (final question in quiz.questions)
              QuizSelectedAnswer(
                questionId: question.id,
                selectedAnswer: selectedAnswers[question.id] ?? '',
              ),
          ],
        ),
      );
      _latestQuizCompletion = savedAttempt;
      _quizAttempts = [
        savedAttempt,
        for (final existing in _quizAttempts)
          if (existing.id != savedAttempt.id) existing,
      ];
      if (config.effectiveBackendMode == AppBackendMode.supabase) {
        await loadCumulativeWeakTopicsFor(user);
      } else {
        _cumulativeWeakTopics = _deriveCumulativeWeakTopics(_quizAttempts);
      }
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
      if (config.effectiveBackendMode == AppBackendMode.supabase) {
        await loadStudyProgressFor(user);
      }
      return true;
    } catch (error) {
      _flashcardReviewErrorMessage = _flashcardReviewMessageFor(error);
      return false;
    } finally {
      _isSavingFlashcardReview = false;
      notifyListeners();
    }
  }

  StudySession? createStudySession({
    required Subject subject,
    required LectureConfidence confidence,
    required String materialId,
  }) {
    final selectedMaterial = materialById(materialId);
    if (selectedMaterial == null ||
        selectedMaterial.subjectId != subject.id ||
        !canGenerateSummaryForMaterial(selectedMaterial)) {
      return null;
    }
    final sessionNumber = ++_sessionCounter;
    final question = _quizFor(subject, selectedMaterial, sessionNumber);
    final session = StudySession(
      id: 'local-session-$sessionNumber',
      subjectId: subject.id,
      materialId: selectedMaterial.id,
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
    _persistActiveStudySession(session);
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
    final subject = _subjectForOrNull(session.subjectId);
    if (subject == null) {
      return;
    }
    if (!session.quizQuestion.options.contains(answer)) return;
    _studySessions[index] = _answerStudySession(session, subject, answer);
    _persistActiveStudySession(_studySessions[index]);
    notifyListeners();
  }

  void completeStudySession(String sessionId) {
    _endStudySession(sessionId);
  }

  void exitStudySession(String sessionId) {
    _endStudySession(sessionId);
  }

  void _endStudySession(String sessionId) {
    final index = _studySessions.indexWhere((item) => item.id == sessionId);
    if (index == -1) return;
    _studySessions.removeAt(index);
    final userId = _materialWorkSessionUserId;
    if (userId != null) {
      _queueStudySessionPersistence(
        () => preferencesStore.clearActiveStudySession(userId),
      );
    }
    notifyListeners();
  }

  Future<void> get studySessionPersistenceIdle => _studySessionPersistence;
  Future<void> get studySessionRestorationIdle => _studySessionRestoration;

  StudySession _answerStudySession(
    StudySession session,
    Subject subject,
    String answer,
  ) {
    final isCorrect = answer == session.quizQuestion.correctAnswer;
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
    return session.copyWith(
      selectedAnswer: answer,
      quizScorePercent: isCorrect ? 100 : 0,
      weakTopics: updatedWeakTopics,
      feedback: isCorrect
          ? 'Correct. This topic is ready for a lighter review.'
          : 'Incorrect. Review the explanation, then retry the flashcards.',
      currentItemIndex: 1,
      completedItemIds: const ['quick_quiz'],
    );
  }

  void _persistActiveStudySession(StudySession session) {
    final userId = _materialWorkSessionUserId;
    if (userId == null) return;
    final snapshot = jsonEncode({
      'version': 1,
      'session_type': 'material_review',
      'session_id': session.id,
      'subject_id': session.subjectId,
      'material_id': session.materialId,
      'confidence': session.confidence.name,
      'current_item_index': session.currentItemIndex,
      'completed_item_ids': session.completedItemIds,
      'selected_answer': session.selectedAnswer,
      'quiz_score_percent': session.quizScorePercent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    _queueStudySessionPersistence(
      () => preferencesStore.saveActiveStudySession(userId, snapshot),
    );
  }

  void _queueStudySessionPersistence(Future<void> Function() operation) {
    _studySessionPersistence = _studySessionPersistence
        .then((_) => operation())
        .catchError((_) {});
  }

  Future<void> _restoreActiveStudySession(AuthUser user) async {
    String? raw;
    try {
      raw = await preferencesStore.loadActiveStudySession(user.id);
    } catch (_) {
      return;
    }
    if (raw == null) return;
    if (_materialWorkSessionUserId != user.id) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final snapshot = Map<String, Object?>.from(decoded);
      const expectedKeys = {
        'version',
        'session_type',
        'session_id',
        'subject_id',
        'material_id',
        'confidence',
        'current_item_index',
        'completed_item_ids',
        'selected_answer',
        'quiz_score_percent',
        'updated_at',
      };
      if (snapshot.length != expectedKeys.length ||
          !expectedKeys.every(snapshot.containsKey) ||
          snapshot['version'] != 1 ||
          snapshot['session_type'] != 'material_review') {
        throw const FormatException();
      }
      final sessionId = snapshot['session_id'];
      final subjectId = snapshot['subject_id'];
      final materialId = snapshot['material_id'];
      final confidenceName = snapshot['confidence'];
      final currentItemIndex = snapshot['current_item_index'];
      final completedRaw = snapshot['completed_item_ids'];
      final selectedAnswer = snapshot['selected_answer'];
      final score = snapshot['quiz_score_percent'];
      final updatedAt = snapshot['updated_at'];
      if (sessionId is! String ||
          subjectId is! String ||
          materialId is! String ||
          confidenceName is! String ||
          currentItemIndex is! int ||
          completedRaw is! List ||
          (selectedAnswer != null && selectedAnswer is! String) ||
          (score != null && score is! int) ||
          updatedAt is! String ||
          DateTime.tryParse(updatedAt) == null) {
        throw const FormatException();
      }
      final sessionMatch = RegExp(
        r'^local-session-([1-9][0-9]*)$',
      ).firstMatch(sessionId);
      final sessionNumber = sessionMatch == null
          ? null
          : int.tryParse(sessionMatch.group(1)!);
      final confidence = LectureConfidence.values
          .where((item) => item.name == confidenceName)
          .firstOrNull;
      final subject = _subjectForOrNull(subjectId);
      final material = materialById(materialId);
      if (sessionNumber == null ||
          confidence == null ||
          subject == null ||
          material == null ||
          material.subjectId != subject.id ||
          !canGenerateSummaryForMaterial(material)) {
        throw const FormatException();
      }
      var restored = StudySession(
        id: sessionId,
        subjectId: subject.id,
        materialId: material.id,
        confidence: confidence,
        summary: _summaryFor(subject, confidence, material),
        studyTimeBlocks: _timeBlocksFor(confidence),
        flashcards: _cardsFor(subject, confidence, material, sessionNumber),
        quizQuestion: _quizFor(subject, material, sessionNumber),
        weakTopics: _initialWeakTopicsFor(subject, confidence),
      );
      final completedItemIds = completedRaw.cast<String>();
      if (selectedAnswer == null) {
        if (score != null ||
            currentItemIndex != 0 ||
            completedItemIds.isNotEmpty) {
          throw const FormatException();
        }
      } else {
        final selected = selectedAnswer as String;
        if (!restored.quizQuestion.options.contains(selected) ||
            currentItemIndex != 1 ||
            completedItemIds.length != 1 ||
            completedItemIds.single != 'quick_quiz') {
          throw const FormatException();
        }
        restored = _answerStudySession(restored, subject, selected);
        if (restored.quizScorePercent != score) throw const FormatException();
      }
      if (_materialWorkSessionUserId != user.id) return;
      _studySessions
        ..clear()
        ..add(restored);
      _sessionCounter = sessionNumber;
      notifyListeners();
    } catch (_) {
      if (_materialWorkSessionUserId != user.id) return;
      _studySessions.clear();
      _sessionCounter = 0;
      _queueStudySessionPersistence(
        () => preferencesStore.clearActiveStudySession(user.id),
      );
    }
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

  String _materialUploadMessageFor(Object error) {
    if (error is MaterialUploadValidationException) return error.message;
    if (error is MaterialUploadException) return error.message;
    return 'Could not upload the selected file.';
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

  String _weakTopicMessageFor(Object error) {
    if (error is WeakTopicRepositoryException) {
      return error.message;
    }
    return 'Could not sync cumulative weak topics.';
  }

  List<CumulativeWeakTopic> _deriveCumulativeWeakTopics(
    List<QuizAttempt> attempts,
  ) {
    final totals =
        <
          String,
          ({String subjectId, String topic, int count, DateTime seen})
        >{};
    final uniqueAttempts = <String>{};
    for (final attempt in attempts.reversed) {
      if (!uniqueAttempts.add(attempt.id)) continue;
      for (final weakTopic in attempt.weakTopicsSnapshot) {
        final display = weakTopic.topic.trim();
        final topicKey = display.toLowerCase();
        if (topicKey.isEmpty || weakTopic.missCount <= 0) continue;
        final identity = '${attempt.subjectId}\u0000$topicKey';
        final existing = totals[identity];
        totals[identity] = (
          subjectId: attempt.subjectId,
          topic: existing?.topic ?? display,
          count: (existing?.count ?? 0) + weakTopic.missCount,
          seen: existing == null || attempt.completedAt.isAfter(existing.seen)
              ? attempt.completedAt
              : existing.seen,
        );
      }
    }
    final topics = [
      for (final entry in totals.entries)
        CumulativeWeakTopic(
          id: 'mock-weak-${entry.key.hashCode}',
          subjectId: entry.value.subjectId,
          topic: entry.value.topic,
          topicKey: entry.value.topic.toLowerCase(),
          missCount: entry.value.count,
          lastSeenAt: entry.value.seen,
        ),
    ];
    topics.sort((left, right) {
      final countOrder = right.missCount.compareTo(left.missCount);
      if (countOrder != 0) return countOrder;
      return right.lastSeenAt.compareTo(left.lastSeenAt);
    });
    return topics;
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
    final fallback = _ai.quizFor(subject).firstOrNull;
    if (material == null && fallback != null) {
      return fallback;
    }
    if (material == null) {
      return QuizQuestion(
        id: 'local-session-$sessionNumber-fallback-quiz',
        subjectId: subject.id,
        question: 'What is the next useful step for this subject?',
        options: const [
          'Review the available material',
          'Skip every source',
          'Delete the subject',
          'Ignore the topic',
        ],
        correctAnswer: 'Review the available material',
        explanation: 'A useful source is needed for a focused study session.',
        difficulty: StudyDifficulty.medium,
      );
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
      difficulty: fallback?.difficulty ?? StudyDifficulty.medium,
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

class _AnalysisActionGuard {
  const _AnalysisActionGuard({required this.id, required this.action});

  final String id;
  final AnalysisExplicitAction action;
}

const _transientAnalysisErrors = {
  AnalysisErrorCode.network,
  AnalysisErrorCode.rateLimited,
  AnalysisErrorCode.serviceUnavailable,
};

class _AnalysisRetryGuard {
  const _AnalysisRetryGuard({
    required this.failures,
    required this.nextAllowedAt,
  });

  final int failures;
  final DateTime nextAllowedAt;
}

enum AppLanguagePreference { system, english, german, russian }

enum AppAppearancePreference { system, light, dark }

extension AppAppearancePreferenceX on AppAppearancePreference {
  static AppAppearancePreference fromPersistedCode(String? code) =>
      switch (code) {
        'light' => AppAppearancePreference.light,
        'dark' => AppAppearancePreference.dark,
        'system' || null => AppAppearancePreference.system,
        _ => AppAppearancePreference.system,
      };

  String get persistedCode => switch (this) {
    AppAppearancePreference.system => 'system',
    AppAppearancePreference.light => 'light',
    AppAppearancePreference.dark => 'dark',
  };

  ThemeMode get themeMode => switch (this) {
    AppAppearancePreference.system => ThemeMode.system,
    AppAppearancePreference.light => ThemeMode.light,
    AppAppearancePreference.dark => ThemeMode.dark,
  };
}

extension AppLanguagePreferenceX on AppLanguagePreference {
  static AppLanguagePreference fromPersistedCode(String? code) {
    return switch (code) {
      'en' => AppLanguagePreference.english,
      'de' => AppLanguagePreference.german,
      'ru' => AppLanguagePreference.russian,
      'system' || null => AppLanguagePreference.system,
      _ => AppLanguagePreference.system,
    };
  }

  String get persistedCode {
    return switch (this) {
      AppLanguagePreference.system => 'system',
      AppLanguagePreference.english => 'en',
      AppLanguagePreference.german => 'de',
      AppLanguagePreference.russian => 'ru',
    };
  }

  Locale? get locale {
    return switch (this) {
      AppLanguagePreference.system => null,
      AppLanguagePreference.english => const Locale('en'),
      AppLanguagePreference.german => const Locale('de'),
      AppLanguagePreference.russian => const Locale('ru'),
    };
  }

  String get label {
    return switch (this) {
      AppLanguagePreference.system => 'System default',
      AppLanguagePreference.english => 'English',
      AppLanguagePreference.german => 'Deutsch',
      AppLanguagePreference.russian =>
        '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
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
