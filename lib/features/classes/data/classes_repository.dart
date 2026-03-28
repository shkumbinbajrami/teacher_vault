import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';

class ClassesRepository {
  ClassesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'classes';

  Future<List<SchoolClass>> listByTeacherId(String teacherId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('teacher_id', teacherId)
        .order('name');
    final list = rows as List<dynamic>;
    return list
        .map((e) => SchoolClass.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SchoolClass?> fetchById({
    required String teacherId,
    required String classId,
  }) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', classId)
        .eq('teacher_id', teacherId)
        .maybeSingle();
    if (row == null) return null;
    return SchoolClass.fromRow(Map<String, dynamic>.from(row));
  }

  Future<SchoolClass> create({
    required String teacherId,
    required String name,
    required String schoolYear,
    String? description,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'teacher_id': teacherId,
          'name': name.trim(),
          'school_year': schoolYear.trim(),
          'description': _nullIfBlank(description),
          'is_active': isActive,
        })
        .select()
        .single();
    return SchoolClass.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> update({
    required String teacherId,
    required String classId,
    required String name,
    required String schoolYear,
    String? description,
    required bool isActive,
  }) async {
    await _client.from(_table).update({
      'name': name.trim(),
      'school_year': schoolYear.trim(),
      'description': _nullIfBlank(description),
      'is_active': isActive,
    }).eq('id', classId).eq('teacher_id', teacherId);
  }

  Future<void> delete({
    required String teacherId,
    required String classId,
  }) async {
    await _client.from(_table).delete().eq('id', classId).eq('teacher_id', teacherId);
  }

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
