import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';

class SubjectsRepository {
  SubjectsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'subjects';

  Future<List<Subject>> listByTeacherId(String teacherId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('teacher_id', teacherId)
        .order('name');
    final list = rows as List<dynamic>;
    return list
        .map((e) => Subject.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Subject?> fetchById({
    required String teacherId,
    required String subjectId,
  }) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', subjectId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (row == null) return null;
    return Subject.fromRow(Map<String, dynamic>.from(row));
  }

  Future<Subject> create({
    required String teacherId,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'name': name.trim(),
          'description': _nullIfBlank(description),
          'is_active': isActive,
        })
        .select()
        .single();
    return Subject.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> update({
    required String teacherId,
    required String subjectId,
    required String name,
    String? description,
    required bool isActive,
  }) async {
    await _client
        .from(_table)
        .update({
          'name': name.trim(),
          'description': _nullIfBlank(description),
          'is_active': isActive,
        })
        .eq('id', subjectId)
        .eq('teacher_id', teacherId);
  }

  Future<void> delete({
    required String teacherId,
    required String subjectId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', subjectId)
        .eq('teacher_id', teacherId);
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
