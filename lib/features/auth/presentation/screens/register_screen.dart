import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/core/utils/auth_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/auth/presentation/providers/register_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _fullNameError(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your name';
    if (v.trim().length < 2) return 'At least 2 characters';
    return null;
  }

  String? _emailError(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email';
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _passwordError(String? v) {
    if (v == null || v.isEmpty) return 'Enter a password';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _confirmError(String? v) {
    if (v != _password.text) return 'Passwords do not match';
    return _passwordError(v);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(registerControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final reg = ref.watch(registerControllerProvider);
    final loading = reg.isLoading;

    ref.listen<AsyncValue<void>>(registerControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev?.isLoading != true) return;
          final session = ref.read(supabaseProvider).auth.currentSession;
          if (session == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Check your email to confirm your account if required.',
                ),
              ),
            );
            context.pop();
          }
          // If session exists, [GoRouter] redirect sends user to home.
        },
        error: (e, _) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
        },
      );
    });

    return Scaffold(
      appBar: TeacherVaultAppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _fullName,
                      label: 'Full name',
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _fullNameError,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: _emailError,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      obscure: true,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: _passwordError,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirm,
                      label: 'Confirm password',
                      obscure: true,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: _confirmError,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Create account',
                      isLoading: loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
