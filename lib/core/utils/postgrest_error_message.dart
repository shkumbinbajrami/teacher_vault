import 'package:supabase_flutter/supabase_flutter.dart';

String postgrestErrorMessage(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }
  final raw = error.toString();
  if (raw.startsWith('Exception:')) {
    return raw.replaceFirst('Exception:', '').trim();
  }
  return raw.isNotEmpty ? raw : 'Something went wrong. Try again.';
}
