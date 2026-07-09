import 'dart:math';

import 'package:ai_study_buddy/core/models/quiz.dart';
import 'package:ai_study_buddy/core/models/quiz_question.dart';
import 'package:ai_study_buddy/features/quizzes/quiz_attempt_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('randomization preserves source values without mutating the quiz', () {
    final originalQuestionOrder = _quiz.questions
        .map((item) => item.id)
        .toList();
    final originalOptions = {
      for (final question in _quiz.questions)
        question.id: List<String>.of(question.options),
    };

    final presentation = QuizAttemptPresentation.randomized(_quiz, Random(42));

    expect(
      presentation.quiz.questions.map((item) => item.id).toSet(),
      originalQuestionOrder.toSet(),
    );
    for (final question in presentation.quiz.questions) {
      expect(_counts(question.options), _counts(originalOptions[question.id]!));
    }
    expect(_quiz.questions.map((item) => item.id), originalQuestionOrder);
    for (final question in _quiz.questions) {
      expect(question.options, originalOptions[question.id]);
    }
    expect(
      presentation.quiz.questions.any(
        (question) => question.options.indexOf(question.correctAnswer) != 0,
      ),
      isTrue,
    );
  });

  test('attempt order is stable and copied lists are unmodifiable', () {
    final presentation = QuizAttemptPresentation.randomized(_quiz, Random(17));
    final questionOrder = presentation.quiz.questions
        .map((item) => item.id)
        .toList();
    final optionOrders = {
      for (final question in presentation.quiz.questions)
        question.id: List<String>.of(question.options),
    };

    expect(presentation.quiz.questions.map((item) => item.id), questionOrder);
    for (final question in presentation.quiz.questions) {
      expect(question.options, optionOrders[question.id]);
    }
    expect(
      () => presentation.quiz.questions.add(_quiz.questions.first),
      throwsUnsupportedError,
    );
    expect(
      () => presentation.quiz.questions.first.options.add('New option'),
      throwsUnsupportedError,
    );
  });

  test('successive attempts consume a new deterministic shuffle sequence', () {
    final random = Random(9);

    final first = QuizAttemptPresentation.randomized(_quiz, random);
    final second = QuizAttemptPresentation.randomized(_quiz, random);

    final firstSignature = _signature(first.quiz);
    final secondSignature = _signature(second.quiz);
    expect(secondSignature, isNot(firstSignature));
  });
}

Map<String, int> _counts(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

String _signature(Quiz quiz) => [
  for (final question in quiz.questions)
    '${question.id}:${question.options.join(',')}',
].join('|');

const _quiz = Quiz(
  id: 'quiz-1',
  subjectId: 'subject-1',
  materialId: 'material-1',
  title: 'Randomization quiz',
  questions: [
    QuizQuestion(
      id: 'question-1',
      subjectId: 'subject-1',
      question: 'Question one',
      options: ['Correct 1', 'Wrong 1A', 'Wrong 1B', 'Wrong 1B'],
      correctAnswer: 'Correct 1',
      explanation: 'Explanation one',
      difficulty: StudyDifficulty.easy,
    ),
    QuizQuestion(
      id: 'question-2',
      subjectId: 'subject-1',
      question: 'Question two',
      options: ['Correct 2', 'Wrong 2A', 'Wrong 2B', 'Wrong 2C'],
      correctAnswer: 'Correct 2',
      explanation: 'Explanation two',
      difficulty: StudyDifficulty.medium,
    ),
    QuizQuestion(
      id: 'question-3',
      subjectId: 'subject-1',
      question: 'Question three',
      options: ['Correct 3', 'Wrong 3A', 'Wrong 3B', 'Wrong 3C'],
      correctAnswer: 'Correct 3',
      explanation: 'Explanation three',
      difficulty: StudyDifficulty.exam,
    ),
  ],
);
