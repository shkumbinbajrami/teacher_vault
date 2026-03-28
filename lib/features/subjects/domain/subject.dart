class Subject {
  const Subject({
    required this.id,
    required this.teacherId,
    required this.name,
    this.description,
    required this.isActive,
  });

  final String id;
  final String teacherId;
  final String name;
  final String? description;
  final bool isActive;

  factory Subject.fromRow(Map<String, dynamic> row) {
    return Subject(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      name: '${row['name']}',
      description: row['description'] as String?,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}
