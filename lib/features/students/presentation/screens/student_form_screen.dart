import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Create ([studentId] == null) or edit existing student.
class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({super.key, this.studentId});

  final String? studentId;

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _avatarUrl = TextEditingController();
  bool _saving = false;
  String? _seededForStudentId;

  bool get _isEdit => widget.studentId != null;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  String? _emailError(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  void _seedFromStudent(String studentId, Student student) {
    if (_seededForStudentId == studentId) return;
    _seededForStudentId = studentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fullName.text = student.fullName;
      _email.text = student.email ?? '';
      _avatarUrl.text = student.avatarUrl ?? '';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref.read(studentsRepositoryProvider).update(
              teacherId: teacher.id,
              studentId: widget.studentId!,
              fullName: _fullName.text,
              email: _email.text,
              avatarUrl: _avatarUrl.text,
            );
        ref.invalidate(studentDetailProvider(widget.studentId!));
      } else {
        await ref.read(studentsRepositoryProvider).create(
              teacherId: teacher.id,
              fullName: _fullName.text,
              email: _email.text,
              avatarUrl: _avatarUrl.text,
            );
      }
      ref.invalidate(studentsListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit student' : 'New student';

    if (_isEdit) {
      final detailAsync = ref.watch(studentDetailProvider(widget.studentId!));
      return Scaffold(
        appBar: TeacherVaultAppBar(title: Text(title)),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
            ),
          ),
          data: (student) {
            if (student == null) {
              return const Center(child: Text('Student not found.'));
            }
            _seedFromStudent(student.id, student);
            return _form(context);
          },
        ),
      );
    }

    return Scaffold(
      appBar: TeacherVaultAppBar(title: Text(title)),
      body: _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _fullName,
                label: 'Full name',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _email,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: _emailError,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _avatarUrl,
                label: 'Avatar URL (optional)',
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _isEdit ? 'Save' : 'Create',
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
