import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);
