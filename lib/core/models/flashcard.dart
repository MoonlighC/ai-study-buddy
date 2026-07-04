class Flashcard {
  const Flashcard({
    required this.id,
    required this.subjectId,
    required this.front,
    required this.back,
    required this.topic,
    required this.isFavorite,
  });

  final String id;
  final String subjectId;
  final String front;
  final String back;
  final String topic;
  final bool isFavorite;

  Flashcard copyWith({bool? isFavorite}) {
    return Flashcard(
      id: id,
      subjectId: subjectId,
      front: front,
      back: back,
      topic: topic,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
