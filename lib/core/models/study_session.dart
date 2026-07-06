import 'flashcard.dart';
import 'quiz_question.dart';
import 'study_time_block.dart';
import 'weak_topic.dart';

enum LectureConfidence {
  understoodEverything,
  mostly,
  aboutHalf,
  completelyLost,
}

extension LectureConfidenceLabel on LectureConfidence {
  String get label {
    return switch (this) {
      LectureConfidence.understoodEverything => 'I understood everything',
      LectureConfidence.mostly => 'Mostly',
      LectureConfidence.aboutHalf => 'About half',
      LectureConfidence.completelyLost => 'I am completely lost',
    };
  }
}

class StudySession {
  const StudySession({
    required this.id,
    required this.subjectId,
    required this.materialId,
    required this.confidence,
    required this.summary,
    required this.studyTimeBlocks,
    required this.flashcards,
    required this.quizQuestion,
    required this.weakTopics,
    this.selectedAnswer,
    this.quizScorePercent,
    this.feedback,
  });

  final String id;
  final String subjectId;
  final String materialId;
  final LectureConfidence confidence;
  final String summary;
  final List<StudyTimeBlock> studyTimeBlocks;
  final List<Flashcard> flashcards;
  final QuizQuestion quizQuestion;
  final List<WeakTopic> weakTopics;
  final String? selectedAnswer;
  final int? quizScorePercent;
  final String? feedback;

  int get totalMinutes {
    return studyTimeBlocks.fold<int>(
      0,
      (total, block) => total + block.minutes,
    );
  }

  bool? get answeredCorrectly {
    final answer = selectedAnswer;
    if (answer == null) {
      return null;
    }
    return answer == quizQuestion.correctAnswer;
  }

  StudySession copyWith({
    String? selectedAnswer,
    int? quizScorePercent,
    List<WeakTopic>? weakTopics,
    String? feedback,
  }) {
    return StudySession(
      id: id,
      subjectId: subjectId,
      materialId: materialId,
      confidence: confidence,
      summary: summary,
      studyTimeBlocks: studyTimeBlocks,
      flashcards: flashcards,
      quizQuestion: quizQuestion,
      weakTopics: weakTopics ?? this.weakTopics,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      quizScorePercent: quizScorePercent ?? this.quizScorePercent,
      feedback: feedback ?? this.feedback,
    );
  }
}
