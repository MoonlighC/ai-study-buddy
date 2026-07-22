enum PersistedStudyActivityType { flashcards, quizDraft, quizMistakeReview }

enum FlashcardTrainingMode { all, firstPassMissed, weak, due, favorites }

class PersistedStudyActivity {
  const PersistedStudyActivity({
    required this.id,
    required this.subjectId,
    required this.materialId,
    required this.type,
    required this.version,
    required this.currentIndex,
    required this.itemIds,
    required this.updatedAt,
    this.attemptId,
    this.quizId,
    this.flashcardMode,
    this.answerVisible = false,
    this.firstPassMissedIds = const [],
    this.knownCount = 0,
    this.notKnownCount = 0,
    this.selectedAnswers = const {},
    this.optionOrders = const {},
    this.completedAt,
  });

  final String id;
  final String subjectId;
  final String materialId;
  final PersistedStudyActivityType type;
  final int version;
  final int currentIndex;
  final List<String> itemIds;
  final DateTime updatedAt;
  final String? attemptId;
  final String? quizId;
  final FlashcardTrainingMode? flashcardMode;
  final bool answerVisible;
  final List<String> firstPassMissedIds;
  final int knownCount;
  final int notKnownCount;
  final Map<String, String> selectedAnswers;
  final Map<String, List<String>> optionOrders;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
  int get totalItems => itemIds.length;
}
