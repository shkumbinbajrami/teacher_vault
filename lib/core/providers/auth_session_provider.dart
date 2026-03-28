import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';

/// Re-emits whenever Supabase auth state changes (login, logout, refresh).
final authSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange.map((event) => event.session);
});
