import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/features/auth/presentation/providers/auth_repository_provider.dart';

final registerControllerProvider =
    NotifierProvider<RegisterController, AsyncValue<void>>(
  RegisterController.new,
);

class RegisterController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            fullName: fullName,
          );
    });
  }
}
