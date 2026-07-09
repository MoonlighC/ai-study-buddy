class QuizQuestion {
  const QuizQuestion({
    required this.id,
    this.quizId,
    required this.subjectId,
    this.materialId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.topic = 'General',
    required this.difficulty,
  });

  final String id;
  final String? quizId;
  final String subjectId;
  final String? materialId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String topic;
  final StudyDifficulty difficulty;
}

enum StudyDifficulty { easy, medium, exam }
