import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';

class AbsencesRepository {
  AbsencesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'absences';

  static const _selectWithContext =
      'id, teacher_id, student_id, class_subject_id, absence_date, reason, '
      'created_at, updated_at, '
      'class_subjects(subjects(name), classes(name))';

  static String _toPgDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<Absence>> listForStudent({
    required String teacherId,
    required String studentId,
    DateTime? fromDate,
    DateTime? toDate,
    String? classSubjectId,
  }) async {
    var q = _client
        .from(_table)
        .select(_selectWithContext)
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId);
    if (fromDate != null) {
      q = q.gte('absence_date', _toPgDate(fromDate));
    }
    if (toDate != null) {
      q = q.lte('absence_date', _toPgDate(toDate));
    }
    if (classSubjectId != null && classSubjectId.isNotEmpty) {
      q = q.eq('class_subject_id', classSubjectId);
    }
    final rows = await q.order('absence_date', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => Absence.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Number of absence rows for any of [classSubjectIds].
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

  Future<Absence?> fetchById({
    required String teacherId,
    required String absenceId,
  }) async {
    final row = await _client
        .from(_table)
        .select(_selectWithContext)
        .eq('id', absenceId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (row == null) return null;
    return Absence.fromRow(Map<String, dynamic>.from(row));
  }

  Future<Absence> create({
    required String teacherId,
    required String studentId,
    required String classSubjectId,
    required DateTime absenceDate,
    String? reason,
  }) async {
    await _assertStudentInClassForSubject(studentId, classSubjectId);

    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'student_id': studentId,
          'class_subject_id': classSubjectId,
          'absence_date': _toPgDate(absenceDate),
          'reason': _nullIfBlank(reason),
        })
        .select(_selectWithContext)
        .single();
    return Absence.fromRow(Map<String, dynamic>.from(row));
  }

  /// Inserts one absence per student (same subject, date, shared [reason]).
  /// Confirms [classSubjectId] belongs to [classId] and each student is enrolled.
  Future<void> createBulkForClass({
    required String teacherId,
    required String classId,
    required String classSubjectId,
    required DateTime absenceDate,
    required List<String> studentIds,
    String? reason,
  }) async {
    final ids = studentIds.toSet().toList();
    if (ids.isEmpty) {
      throw StateError('Select at least one student.');
    }

    final link = await _client
        .from('class_subjects')
        .select('class_id')
        .eq('id', classSubjectId)
        .maybeSingle();
    if (link == null) throw StateError('Class subject not found.');
    final cid = '${link['class_id']}';
    if (cid != classId) {
      throw StateError('This subject is not part of this class.');
    }

    final enrRows = await _client
        .from('class_students')
        .select('student_id')
        .eq('class_id', classId)
        .inFilter('student_id', ids);
    final enrList = enrRows as List<dynamic>;
    final enrolled = enrList
        .map((e) => '${(e as Map<String, dynamic>)['student_id']}')
        .toSet();
    if (enrolled.length != ids.length) {
      throw StateError(
        'Every selected student must be enrolled in this class. Refresh and try again.',
      );
    }

    final reasonValue = _nullIfBlank(reason);
    final dateStr = _toPgDate(absenceDate);
    final payload = ids
        .map(
          (sid) => <String, dynamic>{
            'teacher_id': teacherId,
            'student_id': sid,
            'class_subject_id': classSubjectId,
            'absence_date': dateStr,
            'reason': reasonValue,
          },
        )
        .toList();

    await _client.from(_table).insert(payload);
  }

  Future<void> update({
    required String teacherId,
    required String studentId,
    required String absenceId,
    required String classSubjectId,
    required DateTime absenceDate,
    String? reason,
  }) async {
    await _assertStudentInClassForSubject(studentId, classSubjectId);

    await _client
        .from(_table)
        .update({
          'class_subject_id': classSubjectId,
          'absence_date': _toPgDate(absenceDate),
          'reason': _nullIfBlank(reason),
        })
        .eq('id', absenceId)
        .eq('teacher_id', teacherId);
  }

  Future<void> delete({
    required String teacherId,
    required String absenceId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', absenceId)
        .eq('teacher_id', teacherId);
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

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
