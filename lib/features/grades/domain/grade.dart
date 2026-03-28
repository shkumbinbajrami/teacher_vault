class Grade {
  const Grade({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.classSubjectId,
    required this.gradeValue,
    this.note,
    required this.period,
    this.className,
    this.subjectName,
    this.studentName,
  });

  final String id;
  final String teacherId;
  final String studentId;
  final String classSubjectId;
  final int gradeValue;
  final String? note;
  final int period;

  /// From nested selects when available.
  final String? className;
  final String? subjectName;
  final String? studentName;

  factory Grade.fromRow(Map<String, dynamic> row) {
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

    String? studentName;
    final stRaw = row['students'];
    if (stRaw is Map<String, dynamic>) {
      studentName = stRaw['full_name'] as String?;
    }

    return Grade(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      studentId: '${row['student_id']}',
      classSubjectId: '${row['class_subject_id']}',
      gradeValue: _asInt(row['grade_value']),
      note: row['note'] as String?,
      period: _asInt(row['period']),
      className: className,
      subjectName: subjectName,
      studentName: studentName,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
