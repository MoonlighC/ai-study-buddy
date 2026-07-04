class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.subjectId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
  });

  final String id;
  final String subjectId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final StudyDifficulty difficulty;
}

enum StudyDifficulty { easy, medium, exam }
