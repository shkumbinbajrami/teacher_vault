import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads teacher profile images to Supabase Storage.
///
/// Create a public bucket named [bucketName] in the Supabase dashboard and add
/// policies so authenticated users can `insert` (and optionally `delete`) under
/// `teachers/{their_teacher_id}/`. For local URLs, `getPublicUrl` requires the
/// bucket to be public or you must use signed URLs instead.
class TeacherAvatarStorage {
  TeacherAvatarStorage(this._client);

  final SupabaseClient _client;

  static const String bucketName = 'avatars';

  static const int maxBytes = 4 * 1024 * 1024;

  /// Uploads image bytes and returns the public URL (see bucket setup).
  Future<String> uploadTeacherAvatar({
    required String teacherId,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Image is empty.');
    }
    if (bytes.length > maxBytes) {
      throw StateError('Image must be ${maxBytes ~/ (1024 * 1024)} MB or smaller.');
    }
    final safeExt = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final ext = safeExt.isEmpty ? 'jpg' : safeExt;
    final path =
        'teachers/$teacherId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from(bucketName).getPublicUrl(path);
  }
}
