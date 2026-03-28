import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase / GoTrue errors to a short user-facing string.
String authErrorMessage(Object error) {
  if (error is AuthWeakPasswordException) {
    if (error.reasons.isNotEmpty) {
      return '${error.message} (${error.reasons.join('; ')})';
    }
    return error.message;
  }
  if (error is AuthException) {
    return error.message;
  }
  final raw = error.toString();
  if (raw.startsWith('Exception:')) {
    return raw.replaceFirst('Exception:', '').trim();
  }
  if (raw.isNotEmpty) {
    return raw;
  }
  return 'Something went wrong. Try again.';
}
