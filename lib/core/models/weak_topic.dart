class WeakTopic {
  const WeakTopic({
    required this.subjectId,
    required this.title,
    required this.reason,
  });

  final String subjectId;
  final String title;
  final String reason;
}

class CumulativeWeakTopic {
  const CumulativeWeakTopic({
    required this.id,
    required this.subjectId,
    required this.topic,
    required this.topicKey,
    required this.missCount,
    required this.lastSeenAt,
    this.source = const {},
  });

  final String id;
  final String subjectId;
  final String topic;
  final String topicKey;
  final int missCount;
  final DateTime lastSeenAt;
  final Map<String, dynamic> source;
}
