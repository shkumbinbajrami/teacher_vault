import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

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
        await ref
            .read(studentsRepositoryProvider)
            .update(
              teacherId: teacher.id,
              studentId: widget.studentId!,
              fullName: _fullName.text,
              email: _email.text,
              avatarUrl: _avatarUrl.text,
            );
        ref.invalidate(studentDetailProvider(widget.studentId!));
      } else {
        await ref
            .read(studentsRepositoryProvider)
            .create(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Student' : 'Create Student';
    final subtitle = _isEdit
        ? 'Update details for this student.'
        : 'Add a new student to your workspace.';

    Widget body;
    if (_isEdit) {
      final detailAsync = ref.watch(studentDetailProvider(widget.studentId!));
      body = detailAsync.when(
        loading: () => const TVProgressIndicator(),
        error: (e, _) => Center(
          child: Text(
            postgrestErrorMessage(e),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          _seedFromStudent(student.id, student);
          return _formContent();
        },
      );
    } else {
      body = _formContent();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    TVSecondaryButton(
                      label: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TVCard(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(height: 48),
                          body,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TVTextField(
            controller: _fullName,
            label: 'Full Name',
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          TVTextField(
            controller: _email,
            label: 'Email (Optional)',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailError,
          ),
          const SizedBox(height: 24),
          TVTextField(
            controller: _avatarUrl,
            label: 'Avatar URL (Optional)',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TVSecondaryButton(
                label: 'Cancel',
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 16),
              TVPrimaryButton(
                label: _isEdit ? 'Save Changes' : 'Create Student',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
