import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/class_subjects/domain/subject_class_link.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';

class ClassSubjectsRepository {
  ClassSubjectsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'class_subjects';

  /// Subjects linked to [classId] (scoped to [teacherId] via `subjects.teacher_id`).
  Future<List<Subject>> listSubjectsForClass({
    required String teacherId,
    required String classId,
  }) async {
    final assignments = await listAssignmentsForClass(
      teacherId: teacherId,
      classId: classId,
    );
    return assignments.map((a) => a.subject).toList();
  }

  /// Full `class_subjects` rows with [Subject] (includes `class_subject` id for grades).
  Future<List<ClassSubjectAssignment>> listAssignmentsForClass({
    required String teacherId,
    required String classId,
  }) async {
    final cls = await _client
        .from('classes')
        .select('id')
        .eq('id', classId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (cls == null) throw StateError('Class not found.');

    final links = await _client
        .from(_table)
        .select('id, class_id, subject_id')
        .eq('class_id', classId);
    final linkList = links as List<dynamic>;
    if (linkList.isEmpty) return [];

    final subjectIds = linkList
        .map((e) => '${(e as Map<String, dynamic>)['subject_id']}')
        .toList();

    final subjectRows = await _client
        .from('subjects')
        .select()
        .eq('teacher_id', teacherId)
        .inFilter('id', subjectIds)
        .order('name');
    final list = subjectRows as List<dynamic>;
    final byId = <String, Subject>{
      for (final r in list)
        '${(r as Map<String, dynamic>)['id']}': Subject.fromRow(
          Map<String, dynamic>.from(r),
        ),
    };

    final out = linkList.map((e) {
      final m = e as Map<String, dynamic>;
      final sid = '${m['subject_id']}';
      return ClassSubjectAssignment(
        classSubjectId: '${m['id']}',
        classId: '${m['class_id']}',
        subject: byId[sid]!,
      );
    }).toList();
    out.sort((a, b) => a.subject.name.compareTo(b.subject.name));
    return out;
  }

  Future<String?> classIdForAssignment(String classSubjectId) async {
    final row = await _client
        .from(_table)
        .select('class_id')
        .eq('id', classSubjectId)
        .maybeSingle();
    if (row == null) return null;
    return '${row['class_id']}';
  }

  Future<void> assignSubject({
    required String teacherId,
    required String classId,
    required String subjectId,
  }) async {
    final cls = await _client
        .from('classes')
        .select('id')
        .eq('id', classId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (cls == null) throw StateError('Class not found.');

    final sub = await _client
        .from('subjects')
        .select('id')
        .eq('id', subjectId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (sub == null) throw StateError('Subject not found.');

    try {
      await _client.from(_table).insert({
        'class_id': classId,
        'subject_id': subjectId,
      });
    } on PostgrestException catch (e) {
      final duplicate =
          e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique');
      if (duplicate) {
        throw StateError('This subject is already assigned to the class.');
      }
      rethrow;
    }
  }

  Future<void> removeSubject({
    required String classId,
    required String subjectId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('class_id', classId)
        .eq('subject_id', subjectId);
  }

  /// Total `class_subjects` rows for classes owned by [teacherId].
  Future<int> countAssignmentsForTeacher(String teacherId) async {
    final classRows = await _client
        .from('classes')
        .select('id')
        .eq('teacher_id', teacherId);
    final classList = classRows as List<dynamic>;
    final classIds = classList
        .map((e) => '${(e as Map<String, dynamic>)['id']}')
        .toList();
    if (classIds.isEmpty) return 0;
    final links = await _client
        .from(_table)
        .select('id')
        .inFilter('class_id', classIds);
    return (links as List<dynamic>).length;
  }

  /// Classes that teach [subjectId] (scoped to [teacherId]).
  Future<List<SubjectClassLink>> listClassesUsingSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    final sub = await _client
        .from('subjects')
        .select('id')
        .eq('id', subjectId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (sub == null) return [];

    final links = await _client
        .from(_table)
        .select('id, class_id')
        .eq('subject_id', subjectId);
    final linkList = links as List<dynamic>;
    if (linkList.isEmpty) return [];

    final classIds = linkList
        .map((e) => '${(e as Map<String, dynamic>)['class_id']}')
        .toList();

    final classRows = await _client
        .from('classes')
        .select()
        .eq('teacher_id', teacherId)
        .inFilter('id', classIds)
        .order('name');
    final classesList = classRows as List<dynamic>;
    final byId = <String, SchoolClass>{
      for (final r in classesList)
        '${(r as Map<String, dynamic>)['id']}': SchoolClass.fromRow(
          Map<String, dynamic>.from(r),
        ),
    };

    final out = <SubjectClassLink>[];
    for (final e in linkList) {
      final m = e as Map<String, dynamic>;
      final cid = '${m['class_id']}';
      final sc = byId[cid];
      if (sc != null) {
        out.add(
          SubjectClassLink(classSubjectId: '${m['id']}', schoolClass: sc),
        );
      }
    }
    out.sort((a, b) => a.schoolClass.name.compareTo(b.schoolClass.name));
    return out;
  }

  /// Distinct class count per subject (only classes owned by [teacherId]).
  Future<Map<String, int>> distinctClassCountBySubjectForTeacher(
    String teacherId,
  ) async {
    final classRows = await _client
        .from('classes')
        .select('id')
        .eq('teacher_id', teacherId);
    final classList = classRows as List<dynamic>;
    final classIds = classList
        .map((e) => '${(e as Map<String, dynamic>)['id']}')
        .toList();
    if (classIds.isEmpty) return {};

    final links = await _client
        .from(_table)
        .select('subject_id, class_id')
        .inFilter('class_id', classIds);
    final linkList = links as List<dynamic>;
    final bySubject = <String, Set<String>>{};
    for (final e in linkList) {
      final m = e as Map<String, dynamic>;
      final sid = '${m['subject_id']}';
      final cid = '${m['class_id']}';
      bySubject.putIfAbsent(sid, () => <String>{}).add(cid);
    }
    return {for (final e in bySubject.entries) e.key: e.value.length};
  }
}
