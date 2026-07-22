class StudyProgress {
  const StudyProgress({
    required this.schemaVersion,
    required this.generatedAt,
    required this.global,
    required this.subjects,
    required this.materials,
    required this.historical,
  });

  factory StudyProgress.fromJson(Map<String, dynamic> json) {
    if (_integer(json['schema_version']) != 1) {
      throw const FormatException('Unsupported study progress schema.');
    }
    return StudyProgress(
      schemaVersion: 1,
      generatedAt: _date(json['generated_at']),
      global: ProgressMetrics.fromJson(_map(json['global'])),
      subjects: [
        for (final item in _list(json['subjects']))
          SubjectProgress.fromJson(_map(item)),
      ],
      materials: [
        for (final item in _list(json['materials']))
          MaterialProgress.fromJson(_map(item)),
      ],
      historical: HistoricalProgress.fromJson(_map(json['historical'])),
    );
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final ProgressMetrics global;
  final List<SubjectProgress> subjects;
  final List<MaterialProgress> materials;
  final HistoricalProgress historical;

  SubjectProgress? subjectById(String id) =>
      subjects.where((value) => value.subjectId == id).firstOrNull;
  MaterialProgress? materialById(String id) =>
      materials.where((value) => value.materialId == id).firstOrNull;
}

class ProgressMetrics {
  const ProgressMetrics({
    required this.quizCorrectAnswers,
    required this.quizTotalAnswers,
    required this.completedQuizAttemptCount,
    required this.flashcardKnownCount,
    required this.flashcardNotKnownCount,
    required this.weakCardCount,
    required this.dueCardCount,
    required this.activeSessionCount,
    required this.completedSessionCount,
    required this.quizEvidenceCount,
    required this.flashcardEvidenceCount,
    required this.activeSessions,
    required this.recentCompletedSessions,
    required this.weakTopics,
    this.quizAccuracy,
    this.latestQuizScore,
    this.knowledgeScore,
  });

  factory ProgressMetrics.fromJson(
    Map<String, dynamic> json,
  ) => ProgressMetrics(
    quizCorrectAnswers: _integer(json['quiz_correct_answers']),
    quizTotalAnswers: _integer(json['quiz_total_answers']),
    quizAccuracy: _number(json['quiz_accuracy']),
    completedQuizAttemptCount: _integer(json['completed_quiz_attempt_count']),
    latestQuizScore: _number(json['latest_quiz_score']),
    flashcardKnownCount: _integer(json['flashcard_known_review_count']),
    flashcardNotKnownCount: _integer(json['flashcard_not_known_review_count']),
    weakCardCount: _integer(json['weak_card_count']),
    dueCardCount: _integer(json['due_card_count']),
    activeSessionCount: _integer(json['active_session_count']),
    completedSessionCount: _integer(json['completed_session_count']),
    quizEvidenceCount: _integer(json['quiz_evidence_count']),
    flashcardEvidenceCount: _integer(json['flashcard_evidence_count']),
    activeSessions: _sessions(json['active_sessions']),
    recentCompletedSessions: _sessions(json['recent_completed_sessions']),
    weakTopics: _topics(json['cumulative_weak_topics']),
    knowledgeScore: _number(json['knowledge_score']),
  );

  final int quizCorrectAnswers;
  final int quizTotalAnswers;
  final double? quizAccuracy;
  final int completedQuizAttemptCount;
  final double? latestQuizScore;
  final int flashcardKnownCount;
  final int flashcardNotKnownCount;
  final int weakCardCount;
  final int dueCardCount;
  final int activeSessionCount;
  final int completedSessionCount;
  final List<ProgressSession> activeSessions;
  final List<ProgressSession> recentCompletedSessions;
  final List<ProgressWeakTopic> weakTopics;
  final double? knowledgeScore;
  final int quizEvidenceCount;
  final int flashcardEvidenceCount;
}

class SubjectProgress {
  const SubjectProgress({
    required this.subjectId,
    required this.subjectName,
    required this.metrics,
  });
  factory SubjectProgress.fromJson(Map<String, dynamic> json) =>
      SubjectProgress(
        subjectId: _string(json['subject_id']),
        subjectName: _string(json['subject_name']),
        metrics: _groupMetrics(json),
      );
  final String subjectId;
  final String subjectName;
  final ProgressMetrics metrics;
}

class MaterialProgress {
  const MaterialProgress({
    required this.materialId,
    required this.materialTitle,
    required this.subjectId,
    required this.subjectName,
    required this.metrics,
  });
  factory MaterialProgress.fromJson(Map<String, dynamic> json) =>
      MaterialProgress(
        materialId: _string(json['material_id']),
        materialTitle: _string(json['material_title']),
        subjectId: _string(json['subject_id']),
        subjectName: _string(json['subject_name']),
        metrics: _groupMetrics(json),
      );
  final String materialId;
  final String materialTitle;
  final String subjectId;
  final String subjectName;
  final ProgressMetrics metrics;
}

class ProgressSession {
  const ProgressSession({
    required this.sessionId,
    required this.sessionType,
    required this.subjectId,
    required this.materialId,
    required this.currentProgress,
    required this.totalItems,
    this.subjectName = '',
    this.materialTitle = '',
    this.quizAttemptId,
    this.updatedAt,
    this.completedAt,
  });
  factory ProgressSession.fromJson(Map<String, dynamic> json) =>
      ProgressSession(
        sessionId: _string(json['session_id']),
        sessionType: _string(json['session_type']),
        subjectId: _string(json['subject_id']),
        subjectName: _string(json['subject_name']),
        materialId: _string(json['material_id']),
        materialTitle: _string(json['material_title']),
        currentProgress: _integer(json['current_progress']),
        totalItems: _integer(json['total_items']),
        quizAttemptId: _nullableString(json['quiz_attempt_id']),
        updatedAt: _nullableDate(json['updated_at']),
        completedAt: _nullableDate(json['completed_at']),
      );
  final String sessionId;
  final String sessionType;
  final String subjectId;
  final String subjectName;
  final String materialId;
  final String materialTitle;
  final int currentProgress;
  final int totalItems;
  final String? quizAttemptId;
  final DateTime? updatedAt;
  final DateTime? completedAt;
}

class ProgressWeakTopic {
  const ProgressWeakTopic({
    required this.id,
    required this.topic,
    required this.missCount,
    required this.subjectId,
    required this.materialId,
    this.subjectName = '',
    this.materialTitle = '',
    this.lastSeenAt,
  });
  factory ProgressWeakTopic.fromJson(Map<String, dynamic> json) =>
      ProgressWeakTopic(
        id: _string(json['weak_topic_id']),
        topic: _string(json['topic']),
        missCount: _integer(json['miss_count']),
        subjectId: _string(json['subject_id']),
        subjectName: _string(json['subject_name']),
        materialId: _string(json['material_id']),
        materialTitle: _string(json['material_title']),
        lastSeenAt: _nullableDate(json['last_seen_at']),
      );
  final String id;
  final String topic;
  final int missCount;
  final String subjectId;
  final String subjectName;
  final String materialId;
  final String materialTitle;
  final DateTime? lastSeenAt;
}

class HistoricalProgress {
  const HistoricalProgress({
    required this.label,
    required this.quizCorrectAnswers,
    required this.quizTotalAnswers,
    required this.completedQuizAttemptCount,
    required this.completedSessionCount,
    required this.recentCompletedSessions,
  });
  factory HistoricalProgress.fromJson(Map<String, dynamic> json) =>
      HistoricalProgress(
        label: _string(json['label']),
        quizCorrectAnswers: _integer(json['quiz_correct_answers']),
        quizTotalAnswers: _integer(json['quiz_total_answers']),
        completedQuizAttemptCount: _integer(
          json['completed_quiz_attempt_count'],
        ),
        completedSessionCount: _integer(json['completed_session_count']),
        recentCompletedSessions: _sessions(json['recent_completed_sessions']),
      );
  final String label;
  final int quizCorrectAnswers;
  final int quizTotalAnswers;
  final int completedQuizAttemptCount;
  final int completedSessionCount;
  final List<ProgressSession> recentCompletedSessions;
}

ProgressMetrics _groupMetrics(Map<String, dynamic> json) => ProgressMetrics(
  quizCorrectAnswers: 0,
  quizTotalAnswers: _integer(json['quiz_evidence_count']),
  quizAccuracy: _number(json['quiz_accuracy']),
  completedQuizAttemptCount: _integer(json['attempt_count']),
  flashcardKnownCount: _integer(json['flashcard_known_review_count']),
  flashcardNotKnownCount: _integer(json['flashcard_not_known_review_count']),
  weakCardCount: _integer(json['weak_card_count']),
  dueCardCount: _integer(json['due_card_count']),
  activeSessionCount: _list(json['active_sessions']).length,
  completedSessionCount: _list(json['recent_completed_sessions']).length,
  activeSessions: _sessions(json['active_sessions']),
  recentCompletedSessions: _sessions(json['recent_completed_sessions']),
  weakTopics: _topics(json['weak_topics']),
  knowledgeScore: _number(json['knowledge_score']),
  quizEvidenceCount: _integer(json['quiz_evidence_count']),
  flashcardEvidenceCount: _integer(json['flashcard_evidence_count']),
);

List<ProgressSession> _sessions(Object? value) => [
  for (final item in _list(value)) ProgressSession.fromJson(_map(item)),
];
List<ProgressWeakTopic> _topics(Object? value) => [
  for (final item in _list(value)) ProgressWeakTopic.fromJson(_map(item)),
];
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : throw const FormatException();
List<dynamic> _list(Object? value) => value is List ? value : const [];
String _string(Object? value) => value is String ? value : '';
String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
DateTime _date(Object? value) => DateTime.parse(value.toString()).toUtc();
DateTime? _nullableDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();

// Local/mock-mode compatibility only. Supabase progress never reads these
// values; it is populated exclusively by get_study_progress.
class KnowledgeScore {
  const KnowledgeScore({
    required this.subjectId,
    required this.subjectName,
    required this.scorePercent,
  });
  final String subjectId;
  final String subjectName;
  final int scorePercent;
}
