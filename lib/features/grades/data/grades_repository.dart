import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';

class GradesRepository {
  GradesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'grades';

  /// Select list for nested `class_subjects` + `students` labels (depends on FKs in Supabase).
  static const _selectWithContext =
      'id, teacher_id, student_id, class_subject_id, '
      'grade_value, note, period, created_at, updated_at, '
      'class_subjects(subjects(name), classes(name)), '
      'students(full_name)';

  Future<List<Grade>> listForStudent({
    required String teacherId,
    required String studentId,
  }) async {
    final rows = await _client
        .from(_table)
        .select(_selectWithContext)
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .order('period')
        .order('created_at');
    final list = rows as List<dynamic>;
    return list
        .map((e) => Grade.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Grade>> listForClassSubject({
    required String teacherId,
    required String classSubjectId,
  }) async {
    final rows = await _client
        .from(_table)
        .select(_selectWithContext)
        .eq('teacher_id', teacherId)
        .eq('class_subject_id', classSubjectId)
        .order('period')
        .order('created_at');
    final list = rows as List<dynamic>;
    return list
        .map((e) => Grade.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Grade?> fetchById({
    required String teacherId,
    required String gradeId,
  }) async {
    final row = await _client
        .from(_table)
        .select(_selectWithContext)
        .eq('id', gradeId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (row == null) return null;
    return Grade.fromRow(Map<String, dynamic>.from(row));
  }

  Future<Grade> create({
    required String teacherId,
    required String studentId,
    required String classSubjectId,
    required int gradeValue,
    required int period,
    String? note,
  }) async {
    final link = await _client
        .from('class_subjects')
        .select('class_id')
        .eq('id', classSubjectId)
        .maybeSingle();
    if (link == null) {
      throw StateError('Class subject not found.');
    }
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

    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'student_id': studentId,
          'class_subject_id': classSubjectId,
          'grade_value': gradeValue,
          'period': period,
          'note': _nullIfBlank(note),
        })
        .select(
          'id, teacher_id, student_id, class_subject_id, grade_value, note, period',
        )
        .single();
    return Grade.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> update({
    required String teacherId,
    required String gradeId,
    required int gradeValue,
    required int period,
    String? note,
  }) async {
    await _client
        .from(_table)
        .update({
          'grade_value': gradeValue,
          'period': period,
          'note': _nullIfBlank(note),
        })
        .eq('id', gradeId)
        .eq('teacher_id', teacherId);
  }

  Future<void> delete({
    required String teacherId,
    required String gradeId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', gradeId)
        .eq('teacher_id', teacherId);
  }

  /// Number of grade rows for any of [classSubjectIds].
  Future<int> countForClassSubjectIds({
    required String teacherId,
    required List<String> classSubjectIds,
  }) async {
    if (classSubjectIds.isEmpty) return 0;
    final rows = await _client
        .from(_table)
        .select('id')
        .eq('teacher_id', teacherId)
        .inFilter('class_subject_id', classSubjectIds);
    return (rows as List<dynamic>).length;
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
