class Flashcard {
  const Flashcard({
    required this.id,
    required this.subjectId,
    required this.front,
    required this.back,
    required this.topic,
    required this.isFavorite,
    this.materialId,
    this.difficulty = FlashcardDifficulty.medium,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final String id;
  final String subjectId;
  final String? materialId;
  final String front;
  final String back;
  final String topic;
  final FlashcardDifficulty difficulty;
  final bool isFavorite;
  final int correctCount;
  final int incorrectCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  Flashcard copyWith({
    String? id,
    String? subjectId,
    String? materialId,
    String? front,
    String? back,
    String? topic,
    FlashcardDifficulty? difficulty,
    bool? isFavorite,
    int? correctCount,
    int? incorrectCount,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
  }) {
    return Flashcard(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      materialId: materialId ?? this.materialId,
      front: front ?? this.front,
      back: back ?? this.back,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }
}

enum FlashcardDifficulty { easy, medium, exam }

extension FlashcardDifficultyLabel on FlashcardDifficulty {
  String get label {
    return switch (this) {
      FlashcardDifficulty.easy => 'easy',
      FlashcardDifficulty.medium => 'medium',
      FlashcardDifficulty.exam => 'exam',
    };
  }
}
