import '../core/models/flashcard.dart';
import '../core/models/quiz_question.dart';
import '../core/models/subject.dart';
import 'mock_data.dart';

class MockAiService {
  const MockAiService();

  String summaryFor(Subject subject) {
    return switch (subject.id) {
      'biology' =>
        'Photosynthesis turns light energy into glucose. The chloroplast, carbon dioxide, water, and chlorophyll all work together to store energy for the plant.',
      'math' =>
        'Linear equations describe relationships with a constant rate of change. Solving them means isolating the unknown while keeping both sides balanced.',
      _ =>
        'This lesson focuses on recognizing key vocabulary, grammar patterns, and short answer structures for confident exam responses.',
    };
  }

  List<Flashcard> flashcardsFor(Subject subject) {
    return MockData.flashcards
        .where((flashcard) => flashcard.subjectId == subject.id)
        .toList();
  }

  List<QuizQuestion> quizFor(Subject subject) {
    return MockData.quizQuestions
        .where((question) => question.subjectId == subject.id)
        .toList();
  }

  List<String> examPlanFor(Subject subject) {
    return [
      'Day 1: Review the summary and mark weak topics in ${subject.name}.',
      'Day 2: Study 10 flashcards and favorite cards that need another pass.',
      'Day 3: Take a medium quiz, then read each mistake explanation.',
      'Day 4: Try exam difficulty questions and revisit weak topics.',
    ];
  }
}
