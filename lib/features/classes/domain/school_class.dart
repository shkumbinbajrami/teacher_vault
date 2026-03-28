/// Row from table `classes` (named [SchoolClass] to avoid Dart keyword clash).
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.schoolYear,
    this.description,
    required this.isActive,
  });

  final String id;
  final String teacherId;
  final String name;
  final String schoolYear;
  final String? description;
  final bool isActive;

  factory SchoolClass.fromRow(Map<String, dynamic> row) {
    return SchoolClass(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      name: '${row['name']}',
      schoolYear: '${row['school_year']}',
      description: row['description'] as String?,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}
