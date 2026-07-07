class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.description,
    required this.colorValue,
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;

  Subject copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
