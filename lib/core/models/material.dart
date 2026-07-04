class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    required this.content,
    required this.createdLabel,
  });

  final String id;
  final String subjectId;
  final String title;
  final MaterialKind kind;
  final String content;
  final String createdLabel;
}

enum MaterialKind { pastedText, image, pdf }
