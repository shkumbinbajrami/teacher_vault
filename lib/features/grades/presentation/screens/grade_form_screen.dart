import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Create ([gradeId] == null) or edit existing grade for [studentId].
class GradeFormScreen extends ConsumerStatefulWidget {
  const GradeFormScreen({
    required this.studentId,
    super.key,
    this.gradeId,
  });

  final String studentId;
  final String? gradeId;

  @override
  ConsumerState<GradeFormScreen> createState() => _GradeFormScreenState();
}

class _GradeFormScreenState extends ConsumerState<GradeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _period = TextEditingController();
  final _note = TextEditingController();

  bool _saving = false;
  String? _selectedClassId;
  String? _selectedClassSubjectId;
  bool _seededEdit = false;
  String? _editClassSubjectId;

  bool get _isEdit => widget.gradeId != null;

  @override
  void dispose() {
    _value.dispose();
    _period.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _requiredInt(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'Enter $label';
    final n = int.tryParse(v.trim());
    if (n == null) return '$label must be a number';
    if (n < 1) return '$label must be at least 1';
    return null;
  }

  void _seedFromGrade(Grade grade) {
    if (_seededEdit) return;
    _seededEdit = true;
    _editClassSubjectId = grade.classSubjectId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _value.text = '${grade.gradeValue}';
      _period.text = '${grade.period}';
      _note.text = grade.note ?? '';
    });
  }

  Future<void> _submitForNew() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedClassSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a class and subject.')),
      );
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    final gv = int.parse(_value.text.trim());
    final period = int.parse(_period.text.trim());

    setState(() => _saving = true);
    try {
      await ref.read(gradesRepositoryProvider).create(
            teacherId: teacher.id,
            studentId: widget.studentId,
            classSubjectId: _selectedClassSubjectId!,
            gradeValue: gv,
            period: period,
            note: _note.text,
          );
      ref.invalidate(studentGradesProvider(widget.studentId));
      ref.invalidate(classSubjectGradesProvider(_selectedClassSubjectId!));
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

  Future<void> _submitForEdit(String gradeId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    final gv = int.parse(_value.text.trim());
    final period = int.parse(_period.text.trim());

    setState(() => _saving = true);
    try {
      await ref.read(gradesRepositoryProvider).update(
            teacherId: teacher.id,
            gradeId: gradeId,
            gradeValue: gv,
            period: period,
            note: _note.text,
          );
      ref.invalidate(studentGradesProvider(widget.studentId));
      ref.invalidate(gradeDetailProvider(gradeId));
      if (_editClassSubjectId != null) {
        ref.invalidate(classSubjectGradesProvider(_editClassSubjectId!));
      }
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

  Widget _buildNewForm(BuildContext context) {
    final classesAsync = ref.watch(studentClassesProvider(widget.studentId));
    final assignmentsAsync = _selectedClassId != null
        ? ref.watch(classSubjectAssignmentsProvider(_selectedClassId!))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            classesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
              data: (classes) {
                if (classes.isEmpty) {
                  return Text(
                    'This student is not enrolled in any class yet. Enroll them '
                    'from a class detail screen, then add a grade.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                }
                return DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: classes
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedClassId = v;
                      _selectedClassSubjectId = null;
                    });
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Choose a class' : null,
                );
              },
            ),
            if (_selectedClassId != null && assignmentsAsync != null) ...[
              const SizedBox(height: 16),
              assignmentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                    postgrestErrorMessage(e),
                    textAlign: TextAlign.center,
                  ),
                data: (assignments) {
                  if (assignments.isEmpty) {
                    return Text(
                      'No subjects assigned to this class. Assign subjects from '
                      'the class screen first.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  final validIds =
                      assignments.map((a) => a.classSubjectId).toSet();
                  final current = _selectedClassSubjectId != null &&
                          validIds.contains(_selectedClassSubjectId)
                      ? _selectedClassSubjectId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: current,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: assignments
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.classSubjectId,
                            child: Text(a.subject.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedClassSubjectId = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Choose a subject' : null,
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _value,
              label: 'Grade value',
              keyboardType: TextInputType.number,
              validator: (v) => _requiredInt(v, 'Grade value'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _period,
              label: 'Period',
              keyboardType: TextInputType.number,
              validator: (v) => _requiredInt(v, 'Period'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _note,
              label: 'Note (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Save',
              onPressed: _submitForNew,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, Grade grade) {
    _seedFromGrade(grade);

    final ctxLabel = [
      if (grade.className != null) grade.className,
      if (grade.subjectName != null) grade.subjectName,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ctxLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  ctxLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            AppTextField(
              controller: _value,
              label: 'Grade value',
              keyboardType: TextInputType.number,
              validator: (v) => _requiredInt(v, 'Grade value'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _period,
              label: 'Period',
              keyboardType: TextInputType.number,
              validator: (v) => _requiredInt(v, 'Period'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _note,
              label: 'Note (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Save',
              onPressed: () => _submitForEdit(widget.gradeId!),
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit grade' : 'New grade';

    if (!_isEdit) {
      return Scaffold(
        appBar: TeacherVaultAppBar(title: Text(title)),
        body: _buildNewForm(context),
      );
    }

    final detailAsync = ref.watch(gradeDetailProvider(widget.gradeId!));
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
        data: (grade) {
          if (grade == null) {
            return const Center(child: Text('Grade not found.'));
          }
          if (grade.studentId != widget.studentId) {
            return const Center(child: Text('Grade does not belong to this student.'));
          }
          return _buildEditForm(context, grade);
        },
      ),
    );
  }
}
