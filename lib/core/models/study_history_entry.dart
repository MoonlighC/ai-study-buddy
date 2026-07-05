class StudyHistoryEntry {
  const StudyHistoryEntry({
    required this.label,
    required this.subjectName,
    required this.activitySummary,
    required this.quizScorePercent,
  });

  final String label;
  final String subjectName;
  final String activitySummary;
  final int quizScorePercent;
}
