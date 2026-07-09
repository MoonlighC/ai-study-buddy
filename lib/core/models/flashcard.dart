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
  });

  final String id;
  final String subjectId;
  final String? materialId;
  final String front;
  final String back;
  final String topic;
  final FlashcardDifficulty difficulty;
  final bool isFavorite;

  Flashcard copyWith({
    String? id,
    String? subjectId,
    String? materialId,
    String? front,
    String? back,
    String? topic,
    FlashcardDifficulty? difficulty,
    bool? isFavorite,
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
