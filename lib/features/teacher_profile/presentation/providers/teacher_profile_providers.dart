import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/auth_session_provider.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/teacher_profile/data/teacher_repository.dart';
import 'package:teacher_vault/features/teacher_profile/domain/teacher.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => TeacherRepository(ref.watch(supabaseProvider)),
);

/// When signed in: ensures a `teachers` row exists (insert if missing), then returns it.
final currentTeacherProvider = FutureProvider<Teacher?>((ref) async {
  ref.watch(authSessionProvider);
  final user = ref.watch(supabaseProvider).auth.currentUser;
  if (user == null) return null;
  return ref
      .watch(teacherRepositoryProvider)
      .ensureTeacherProfile(
        userId: user.id,
        email: user.email,
        userMetadata: user.userMetadata,
      );
});

final profileUpdateControllerProvider =
    NotifierProvider<ProfileUpdateController, AsyncValue<void>>(
      ProfileUpdateController.new,
    );

class ProfileUpdateController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit({
    required String teacherId,
    required String fullName,
    required String email,
    required String avatarUrl,
    required String bio,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(teacherRepositoryProvider)
          .updateProfile(
            teacherId: teacherId,
            fullName: fullName,
            email: email,
            avatarUrl: avatarUrl,
            bio: bio,
          );
      ref.invalidate(currentTeacherProvider);
    });
  }
}
