import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/students/domain/student.dart';

class StudentsRepository {
  StudentsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'students';

  Future<List<Student>> listByTeacherId(String teacherId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('teacher_id', teacherId)
        .order('full_name');
    final list = rows as List<dynamic>;
    return list
        .map((e) => Student.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Student?> fetchById({
    required String teacherId,
    required String studentId,
  }) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', studentId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (row == null) return null;
    return Student.fromRow(Map<String, dynamic>.from(row));
  }

  Future<Student> create({
    required String teacherId,
    required String fullName,
    String? email,
    String? avatarUrl,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'full_name': fullName.trim(),
          'email': _nullIfBlank(email),
          'avatar_url': _nullIfBlank(avatarUrl),
        })
        .select()
        .single();
    return Student.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> update({
    required String teacherId,
    required String studentId,
    required String fullName,
    String? email,
    String? avatarUrl,
  }) async {
    await _client
        .from(_table)
        .update({
          'full_name': fullName.trim(),
          'email': _nullIfBlank(email),
          'avatar_url': _nullIfBlank(avatarUrl),
        })
        .eq('id', studentId)
        .eq('teacher_id', teacherId);
  }

  Future<void> delete({
    required String teacherId,
    required String studentId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', studentId)
        .eq('teacher_id', teacherId);
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
