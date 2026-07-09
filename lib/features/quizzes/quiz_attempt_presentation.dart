import 'dart:math';

import '../../core/models/quiz.dart';
import '../../core/models/quiz_question.dart';

class QuizAttemptPresentation {
  QuizAttemptPresentation.randomized(Quiz source, Random random)
    : quiz = _randomizedQuiz(source, random);

  final Quiz quiz;

  static Quiz _randomizedQuiz(Quiz source, Random random) {
    final questions = List<QuizQuestion>.of(source.questions)..shuffle(random);
    final randomizedQuestions = <QuizQuestion>[
      for (final question in questions) _randomizedQuestion(question, random),
    ];

    return Quiz(
      id: source.id,
      subjectId: source.subjectId,
      materialId: source.materialId,
      title: source.title,
      questions: List<QuizQuestion>.unmodifiable(randomizedQuestions),
    );
  }

  static QuizQuestion _randomizedQuestion(QuizQuestion source, Random random) {
    final options = List<String>.of(source.options)..shuffle(random);
    return QuizQuestion(
      id: source.id,
      quizId: source.quizId,
      subjectId: source.subjectId,
      materialId: source.materialId,
      question: source.question,
      options: List<String>.unmodifiable(options),
      correctAnswer: source.correctAnswer,
      explanation: source.explanation,
      topic: source.topic,
      difficulty: source.difficulty,
    );
  }
}
