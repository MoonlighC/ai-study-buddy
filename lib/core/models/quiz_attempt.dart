class QuizAttemptAnswer {
  const QuizAttemptAnswer({
    required this.questionId,
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.topic,
  });

  final String questionId;
  final String question;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String topic;

  Map<String, Object> toJson() => {
    'question_id': questionId,
    'question': question,
    'selected_answer': selectedAnswer,
    'correct_answer': correctAnswer,
    'is_correct': isCorrect,
    'topic': topic,
  };

  factory QuizAttemptAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAttemptAnswer(
      questionId: _stringValue(json['question_id']),
      question: _stringValue(json['question']),
      selectedAnswer: _stringValue(json['selected_answer']),
      correctAnswer: _stringValue(json['correct_answer']),
      isCorrect: json['is_correct'] == true,
      topic: _stringValue(json['topic']),
    );
  }
}

class QuizWeakTopicSnapshot {
  const QuizWeakTopicSnapshot({required this.topic, required this.missCount});

  final String topic;
  final int missCount;

  Map<String, Object> toJson() => {'topic': topic, 'miss_count': missCount};

  factory QuizWeakTopicSnapshot.fromJson(Map<String, dynamic> json) {
    final rawCount = json['miss_count'];
    return QuizWeakTopicSnapshot(
      topic: _stringValue(json['topic']),
      missCount: rawCount is num
          ? rawCount.toInt().clamp(0, 1 << 31).toInt()
          : 0,
    );
  }
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.subjectId,
    required this.score,
    required this.totalQuestions,
    required this.correctQuestions,
    required this.startedAt,
    required this.completedAt,
    required this.answers,
    required this.weakTopicsSnapshot,
  });

  final String id;
  final String quizId;
  final String subjectId;
  final double score;
  final int totalQuestions;
  final int correctQuestions;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<QuizAttemptAnswer> answers;
  final List<QuizWeakTopicSnapshot> weakTopicsSnapshot;

  QuizAttempt copyWith({String? id}) {
    return QuizAttempt(
      id: id ?? this.id,
      quizId: quizId,
      subjectId: subjectId,
      score: score,
      totalQuestions: totalQuestions,
      correctQuestions: correctQuestions,
      startedAt: startedAt,
      completedAt: completedAt,
      answers: answers,
      weakTopicsSnapshot: weakTopicsSnapshot,
    );
  }
}

String _stringValue(Object? value) => value is String ? value : '';
