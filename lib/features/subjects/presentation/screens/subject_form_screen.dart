import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subject_detail_providers.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class SubjectFormScreen extends ConsumerStatefulWidget {
  const SubjectFormScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  ConsumerState<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends ConsumerState<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _seededForSubjectId;

  bool get _isEdit => widget.subjectId != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(Subject subject) {
    if (_seededForSubjectId == subject.id) return;
    _seededForSubjectId = subject.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text = subject.name;
      _description.text = subject.description ?? '';
      _isActive = subject.isActive;
      setState(() {});
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref.read(subjectsRepositoryProvider).update(
              teacherId: teacher.id,
              subjectId: widget.subjectId!,
              name: _name.text,
              description: _description.text,
              isActive: _isActive,
            );
        ref.invalidate(subjectDetailProvider(widget.subjectId!));
        ref.invalidate(
          subjectProfileSnapshotProvider(widget.subjectId!),
        );
      } else {
        await ref.read(subjectsRepositoryProvider).create(
              teacherId: teacher.id,
              name: _name.text,
              description: _description.text,
              isActive: _isActive,
            );
      }
      ref.invalidate(subjectsListProvider);
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
    final title = _isEdit ? 'Edit subject' : 'New subject';

    if (_isEdit) {
      final detailAsync = ref.watch(subjectDetailProvider(widget.subjectId!));
      return Scaffold(
        appBar: TeacherVaultAppBar(title: Text(title)),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                postgrestErrorMessage(e),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (s) {
            if (s == null) {
              return const Center(child: Text('Subject not found.'));
            }
            _seed(s);
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
                controller: _name,
                label: 'Subject name',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _description,
                label: 'Description (optional)',
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
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
