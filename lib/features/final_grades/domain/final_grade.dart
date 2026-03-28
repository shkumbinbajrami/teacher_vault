/// Row in `final_grades` (year summary per student × class–subject).
class FinalGrade {
  const FinalGrade({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.classSubjectId,
    this.period1,
    this.period2,
    this.period3,
    this.finalMark,
  });

  final String id;
  final String teacherId;
  final String studentId;
  final String classSubjectId;
  final int? period1;
  final int? period2;
  final int? period3;

  /// DB column `final`.
  final int? finalMark;

  factory FinalGrade.fromRow(Map<String, dynamic> row) {
    return FinalGrade(
      id: '${row['id']}',
      teacherId: '${row['teacher_id']}',
      studentId: '${row['student_id']}',
      classSubjectId: '${row['class_subject_id']}',
      period1: _nullableInt(row['period1']),
      period2: _nullableInt(row['period2']),
      period3: _nullableInt(row['period3']),
      finalMark: _nullableInt(row['final']),
    );
  }

  static int? _nullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }
}
