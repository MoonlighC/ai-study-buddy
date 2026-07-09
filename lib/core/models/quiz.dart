import 'quiz_question.dart';

class Quiz {
  const Quiz({
    required this.id,
    required this.subjectId,
    required this.materialId,
    required this.title,
    required this.questions,
  });

  final String id;
  final String subjectId;
  final String materialId;
  final String title;
  final List<QuizQuestion> questions;

  int get questionCount => questions.length;
}
