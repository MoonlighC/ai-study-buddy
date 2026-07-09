class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    required this.content,
    required this.createdLabel,
    this.summary,
  });

  final String id;
  final String subjectId;
  final String title;
  final MaterialKind kind;
  final String content;
  final String createdLabel;
  final String? summary;

  StudyMaterial copyWith({
    String? id,
    String? subjectId,
    String? title,
    MaterialKind? kind,
    String? content,
    String? createdLabel,
    String? summary,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      createdLabel: createdLabel ?? this.createdLabel,
      summary: summary ?? this.summary,
    );
  }
}

enum MaterialKind { pastedText, image, pdf }
