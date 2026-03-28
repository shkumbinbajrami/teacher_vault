import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/features/teacher_profile/domain/teacher.dart';

class TeacherRepository {
  TeacherRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'teachers';

  /// Ensures a `teachers` row exists for [userId] (typical right after sign-up / sign-in).
  ///
  /// Inserts `user_id`, `full_name`, optional `email` (from auth), and `is_active: true`.
  /// `full_name` prefers [userMetadata]`['full_name']`, else [email] local-part, else `'Teacher'`.
  Future<Teacher> ensureTeacherProfile({
    required String userId,
    String? email,
    Map<String, dynamic>? userMetadata,
  }) async {
    final existing = await fetchByUserId(userId);
    if (existing != null) return existing;

    final defaultName = _resolveDisplayName(
      email: email,
      userMetadata: userMetadata,
    );

    try {
      final row = await _client.from(_table).insert({
        'user_id': userId,
        'full_name': defaultName,
        'email': email,
        'is_active': true,
      }).select().maybeSingle();

      if (row != null) {
        return Teacher.fromRow(Map<String, dynamic>.from(row));
      }
    } on PostgrestException catch (e) {
      final duplicate = e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique');
      if (duplicate) {
        final retry = await fetchByUserId(userId);
        if (retry != null) return retry;
      }
      rethrow;
    }

    final after = await fetchByUserId(userId);
    if (after != null) return after;
    throw StateError('Could not create or load teacher profile.');
  }

  static String _resolveDisplayName({
    String? email,
    Map<String, dynamic>? userMetadata,
  }) {
    final meta = userMetadata?['full_name'];
    if (meta is String && meta.trim().isNotEmpty) return meta.trim();
    return _defaultDisplayName(email);
  }

  static String _defaultDisplayName(String? email) {
    if (email == null || email.isEmpty) return 'Teacher';
    final at = email.indexOf('@');
    if (at <= 0) return 'Teacher';
    return email.substring(0, at);
  }

  Future<Teacher?> fetchByUserId(String userId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Teacher.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> updateProfile({
    required String teacherId,
    required String fullName,
    required String email,
    required String avatarUrl,
    required String bio,
  }) async {
    await _client.from(_table).update({
      'full_name': _nullIfBlank(fullName),
      'email': _nullIfBlank(email),
      'avatar_url': _nullIfBlank(avatarUrl),
      'bio': _nullIfBlank(bio),
    }).eq('id', teacherId);
  }

  /// Persists only [avatar_url] (e.g. right after a Storage upload).
  Future<void> updateAvatarUrl({
    required String teacherId,
    required String? avatarUrl,
  }) async {
    await _client.from(_table).update({
      'avatar_url': _nullIfBlank(avatarUrl ?? ''),
    }).eq('id', teacherId);
  }

  static String? _nullIfBlank(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
