import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/students/domain/student.dart';

class ClassStudentsRepository {
  ClassStudentsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'class_students';

  Future<List<Student>> listEnrolledStudents({
    required String teacherId,
    required String classId,
  }) async {
    final links = await _client
        .from(_table)
        .select('student_id')
        .eq('class_id', classId);
    final linkList = links as List<dynamic>;
    if (linkList.isEmpty) return [];

    final ids = linkList
        .map((e) => '${(e as Map<String, dynamic>)['student_id']}')
        .toList();

    final rows = await _client
        .from('students')
        .select()
        .eq('teacher_id', teacherId)
        .inFilter('id', ids)
        .order('full_name');
    final students = rows as List<dynamic>;
    return students
        .map((e) => Student.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> enroll({
    required String teacherId,
    required String classId,
    required String studentId,
  }) async {
    final cls = await _client
        .from('classes')
        .select('id')
        .eq('id', classId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (cls == null) {
      throw StateError('Class not found.');
    }
    final st = await _client
        .from('students')
        .select('id')
        .eq('id', studentId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (st == null) {
      throw StateError('Student not found.');
    }

    try {
      await _client.from(_table).insert({
        'class_id': classId,
        'student_id': studentId,
      });
    } on PostgrestException catch (e) {
      final duplicate = e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique');
      if (duplicate) {
        throw StateError('This student is already in the class.');
      }
      rethrow;
    }
  }

  /// Classes the [studentId] is enrolled in (for this [teacherId]).
  Future<List<SchoolClass>> listClassesForStudent({
    required String teacherId,
    required String studentId,
  }) async {
    final links =
        await _client.from(_table).select('class_id').eq('student_id', studentId);
    final linkList = links as List<dynamic>;
    if (linkList.isEmpty) return [];

    final ids = linkList
        .map((e) => '${(e as Map<String, dynamic>)['class_id']}')
        .toSet()
        .toList();

    final rows = await _client
        .from('classes')
        .select()
        .eq('teacher_id', teacherId)
        .inFilter('id', ids)
        .order('name');
    final list = rows as List<dynamic>;
    return list
        .map((e) => SchoolClass.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> removeStudent({
    required String classId,
    required String studentId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('class_id', classId)
        .eq('student_id', studentId);
  }

  /// Distinct students enrolled in any of [classIds] (same person in two classes counts once).
  Future<int> distinctEnrolledStudentCountForClasses({
    required List<String> classIds,
  }) async {
    if (classIds.isEmpty) return 0;
    final links =
        await _client.from(_table).select('student_id').inFilter('class_id', classIds);
    final linkList = links as List<dynamic>;
    final set = <String>{};
    for (final e in linkList) {
      set.add('${(e as Map<String, dynamic>)['student_id']}');
    }
    return set.length;
  }
}
