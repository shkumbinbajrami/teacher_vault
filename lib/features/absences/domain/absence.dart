class Absence {
  const Absence({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.classSubjectId,
    required this.absenceDate,
    this.reason,
    this.className,
    this.subjectName,
  });

  final String id;
  final String teacherId;
  final String studentId;
  final String classSubjectId;
  final DateTime absenceDate;
  final String? reason;

  final String? className;
  final String? subjectName;

  factory Absence.fromRow(Map<String, dynamic> row) {
    final csRaw = row['class_subjects'];
    Map<String, dynamic>? cs;
    if (csRaw is Map<String, dynamic>) cs = csRaw;

    String? subjectName;
    String? className;
    if (cs != null) {
      final sub = cs['subjects'];
      if (sub is Map<String, dynamic>) {
        subjectName = sub['name'] as String?;
      }
      final cl = cs['classes'];
      if (cl is Map<String, dynamic>) {
        className = cl['name'] as String?;
      }
    }

    return Absence(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      studentId: '${row['student_id']}',
      classSubjectId: '${row['class_subject_id']}',
      absenceDate: _parseDate(row['absence_date']),
      reason: row['reason'] as String?,
      className: className,
      subjectName: subjectName,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    final s = '$v';
    if (s.length >= 10) {
      return DateTime.parse(s.substring(0, 10));
    }
    return DateTime.parse(s);
  }
}
