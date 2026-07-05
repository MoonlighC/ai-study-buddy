import '../core/models/flashcard.dart';
import '../core/models/study_time_block.dart';
import '../core/models/quiz_question.dart';
import '../core/models/subject.dart';
import '../core/models/weak_topic.dart';
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

  List<StudyTimeBlock> studyTimeBlocks() {
    return MockData.studyTimeBlocks;
  }

  List<WeakTopic> weakTopicsFor(Subject subject) {
    return MockData.weakTopics
        .where((topic) => topic.subjectId == subject.id)
        .toList();
  }

  int quizScoreFor(Subject subject) {
    return switch (subject.id) {
      'math' => 60,
      'german' => 90,
      _ => 80,
    };
  }

  String mistakeExplanationFor(Subject subject) {
    return switch (subject.id) {
      'math' =>
        'The mistake happened when only one side of the equation changed. Repeat the same operation on both sides to keep it balanced.',
      'german' =>
        'The verb belongs at the end of the subordinate clause after "weil".',
      _ =>
        'Photosynthesis uses carbon dioxide and water to make glucose. Oxygen is released as a result.',
    };
  }

  String aiTeacherAnswerFor(Subject subject) {
    return 'Think of ${subject.name} as a small chain of causes. Start with the key idea, test it with one example, then explain why the wrong answer is tempting but not correct.';
  }
}
