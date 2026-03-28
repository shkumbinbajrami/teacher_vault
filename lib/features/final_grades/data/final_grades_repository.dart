import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_suggestions.dart';

class FinalGradesRepository {
  FinalGradesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'final_grades';

  Future<FinalGrade?> fetchForStudentSubject({
    required String teacherId,
    required String studentId,
    required String classSubjectId,
  }) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .eq('class_subject_id', classSubjectId)
        .maybeSingle();
    if (row == null) return null;
    return FinalGrade.fromRow(Map<String, dynamic>.from(row));
  }

  /// For each of periods 1–3: arithmetic mean of every `grades.grade_value` row with that
  /// same `period` (same student, class–subject). Final suggestion is the mean of whichever
  /// of those three averages exist (any subset, any order).
  Future<FinalGradeSuggestions> computeSuggestionsFromGrades({
    required String teacherId,
    required String studentId,
    required String classSubjectId,
  }) async {
    final rows = await _client
        .from('grades')
        .select('grade_value, period')
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .eq('class_subject_id', classSubjectId);
    final list = rows as List<dynamic>;
    final byPeriod = <int, List<int>>{
      for (var p = 1; p <= 3; p++) p: <int>[],
    };
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final p = _asInt(m['period']);
      if (p < 1 || p > 3) continue;
      byPeriod[p]!.add(_asInt(m['grade_value']));
    }

    int? periodAvg(List<int> values) {
      if (values.isEmpty) return null;
      final sum = values.fold<int>(0, (a, b) => a + b);
      return (sum / values.length).round();
    }

    final p1 = periodAvg(byPeriod[1]!);
    final p2 = periodAvg(byPeriod[2]!);
    final p3 = periodAvg(byPeriod[3]!);
    final present = [p1, p2, p3].whereType<int>().toList();
    final f = present.isEmpty
        ? null
        : (present.reduce((a, b) => a + b) / present.length).round();

    return FinalGradeSuggestions(
      period1: p1,
      period2: p2,
      period3: p3,
      finalMark: f,
    );
  }

  /// Inserts or updates the single row for this student × class–subject.
  Future<FinalGrade> upsert({
    required String teacherId,
    required String studentId,
    required String classSubjectId,
    int? period1,
    int? period2,
    int? period3,
    int? finalMark,
  }) async {
    await _assertStudentInClassForSubject(studentId, classSubjectId);

    final existing = await fetchForStudentSubject(
      teacherId: teacherId,
      studentId: studentId,
      classSubjectId: classSubjectId,
    );

    if (existing != null) {
      await _client.from(_table).update({
        'period1': period1,
        'period2': period2,
        'period3': period3,
        'final': finalMark,
      }).eq('id', existing.id).eq('teacher_id', teacherId);

      final again = await fetchForStudentSubject(
        teacherId: teacherId,
        studentId: studentId,
        classSubjectId: classSubjectId,
      );
      return again!;
    }

    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'student_id': studentId,
          'class_subject_id': classSubjectId,
          'period1': period1,
          'period2': period2,
          'period3': period3,
          'final': finalMark,
        })
        .select()
        .single();
    return FinalGrade.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> _assertStudentInClassForSubject(
    String studentId,
    String classSubjectId,
  ) async {
    final link = await _client
        .from('class_subjects')
        .select('class_id')
        .eq('id', classSubjectId)
        .maybeSingle();
    if (link == null) throw StateError('Class subject not found.');
    final cid = '${link['class_id']}';
    final enr = await _client
        .from('class_students')
        .select('class_id')
        .eq('class_id', cid)
        .eq('student_id', studentId)
        .maybeSingle();
    if (enr == null) {
      throw StateError('Student is not enrolled in this class.');
    }
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
