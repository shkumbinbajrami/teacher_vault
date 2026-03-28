import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class ClassFormScreen extends ConsumerStatefulWidget {
  const ClassFormScreen({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends ConsumerState<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _schoolYear = TextEditingController();
  final _description = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _seededForClassId;

  bool get _isEdit => widget.classId != null;

  @override
  void dispose() {
    _name.dispose();
    _schoolYear.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(SchoolClass schoolClass) {
    if (_seededForClassId == schoolClass.id) return;
    _seededForClassId = schoolClass.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text = schoolClass.name;
      _schoolYear.text = schoolClass.schoolYear;
      _description.text = schoolClass.description ?? '';
      _isActive = schoolClass.isActive;
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
        await ref.read(classesRepositoryProvider).update(
              teacherId: teacher.id,
              classId: widget.classId!,
              name: _name.text,
              schoolYear: _schoolYear.text,
              description: _description.text,
              isActive: _isActive,
            );
        ref.invalidate(classDetailProvider(widget.classId!));
      } else {
        await ref.read(classesRepositoryProvider).create(
              teacherId: teacher.id,
              name: _name.text,
              schoolYear: _schoolYear.text,
              description: _description.text,
              isActive: _isActive,
            );
      }
      ref.invalidate(classesListProvider);
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
    final title = _isEdit ? 'Edit class' : 'New class';

    if (_isEdit) {
      final detailAsync = ref.watch(classDetailProvider(widget.classId!));
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
          data: (c) {
            if (c == null) {
              return const Center(child: Text('Class not found.'));
            }
            _seed(c);
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
                label: 'Class name',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _schoolYear,
                label: 'School year',
                textInputAction: TextInputAction.next,
                hint: 'e.g. 2025–2026',
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
