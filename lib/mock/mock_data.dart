import '../core/models/flashcard.dart';
import '../core/models/material.dart';
import '../core/models/quiz_question.dart';
import '../core/models/subject.dart';
import '../core/models/usage_log.dart';

class MockData {
  static const subjects = [
    Subject(
      id: 'biology',
      name: 'Biology',
      description: 'Cells, ecosystems, genetics, and exam prep.',
      colorValue: 0xFF16A34A,
    ),
    Subject(
      id: 'math',
      name: 'Math',
      description: 'Equations, functions, geometry, and practice sets.',
      colorValue: 0xFF2563EB,
    ),
    Subject(
      id: 'german',
      name: 'German',
      description: 'Vocabulary, grammar, texts, and oral practice.',
      colorValue: 0xFFDB2777,
    ),
  ];

  static const materials = [
    StudyMaterial(
      id: 'bio-lecture-1',
      subjectId: 'biology',
      title: 'Photosynthesis lecture notes',
      kind: MaterialKind.pastedText,
      content: 'Plants convert light, water, and carbon dioxide into glucose.',
      createdLabel: 'Today',
    ),
    StudyMaterial(
      id: 'math-lecture-1',
      subjectId: 'math',
      title: 'Linear equations worksheet',
      kind: MaterialKind.pastedText,
      content: 'Solving equations requires inverse operations.',
      createdLabel: 'Yesterday',
    ),
    StudyMaterial(
      id: 'german-lecture-1',
      subjectId: 'german',
      title: 'Short story vocabulary',
      kind: MaterialKind.pastedText,
      content: 'Vocabulary and sentence starters for text analysis.',
      createdLabel: '2 days ago',
    ),
  ];

  static const flashcards = [
    Flashcard(
      id: 'bio-card-1',
      subjectId: 'biology',
      front: 'What is photosynthesis?',
      back: 'The process plants use to convert light energy into glucose.',
      topic: 'Energy conversion',
      isFavorite: true,
    ),
    Flashcard(
      id: 'bio-card-2',
      subjectId: 'biology',
      front: 'Where does photosynthesis happen?',
      back: 'Inside chloroplasts, mainly in leaf cells.',
      topic: 'Cell organelles',
      isFavorite: false,
    ),
    Flashcard(
      id: 'math-card-1',
      subjectId: 'math',
      front: 'What is the goal when solving an equation?',
      back: 'Isolate the unknown while keeping both sides equal.',
      topic: 'Equations',
      isFavorite: true,
    ),
    Flashcard(
      id: 'german-card-1',
      subjectId: 'german',
      front: 'What does "weil" introduce?',
      back: 'A subordinate clause with the conjugated verb at the end.',
      topic: 'Grammar',
      isFavorite: true,
    ),
  ];

  static const quizQuestions = [
    QuizQuestion(
      id: 'bio-quiz-1',
      subjectId: 'biology',
      question: 'Which input is required for photosynthesis?',
      options: ['Oxygen', 'Carbon dioxide', 'Protein', 'Salt'],
      correctAnswer: 'Carbon dioxide',
      explanation: 'Plants use carbon dioxide and water to make glucose.',
      difficulty: StudyDifficulty.easy,
    ),
    QuizQuestion(
      id: 'math-quiz-1',
      subjectId: 'math',
      question: 'What keeps an equation balanced?',
      options: [
        'Changing only the left side',
        'Using the same operation on both sides',
        'Removing the equals sign',
        'Rounding every number',
      ],
      correctAnswer: 'Using the same operation on both sides',
      explanation: 'Both sides must remain equal after each step.',
      difficulty: StudyDifficulty.medium,
    ),
    QuizQuestion(
      id: 'german-quiz-1',
      subjectId: 'german',
      question: 'Where does the conjugated verb go in a "weil" clause?',
      options: ['First', 'Second', 'At the end', 'It is omitted'],
      correctAnswer: 'At the end',
      explanation: '"Weil" creates a subordinate clause in German.',
      difficulty: StudyDifficulty.exam,
    ),
  ];

  static const usageLogs = [
    UsageLog(
      userId: 'mock-user',
      feature: 'flashcards',
      model: 'mock-local',
      inputTokens: 0,
      outputTokens: 0,
      estimatedCostUsd: 0,
    ),
  ];
}
