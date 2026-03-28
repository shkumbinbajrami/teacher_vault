class Student {
  const Student({
    required this.id,
    required this.teacherId,
    required this.fullName,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String teacherId;
  final String fullName;
  final String? email;
  final String? avatarUrl;

  factory Student.fromRow(Map<String, dynamic> row) {
    return Student(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      fullName: (row['full_name'] as String?)?.trim() ?? '',
      email: row['email'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
