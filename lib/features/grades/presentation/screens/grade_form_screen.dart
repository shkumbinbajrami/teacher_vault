import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class GradeFormScreen extends ConsumerStatefulWidget {
  const GradeFormScreen({required this.studentId, super.key, this.gradeId});

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
      await ref
          .read(gradesRepositoryProvider)
          .create(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
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
      await ref
          .read(gradesRepositoryProvider)
          .update(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
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

    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.outlineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.outlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Class & Subject',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          classesAsync.when(
            loading: () => const TVProgressIndicator(),
            error: (e, _) => Text(
              postgrestErrorMessage(e),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            data: (classes) {
              if (classes.isEmpty) {
                return Text(
                  'This student is not enrolled in any class yet. Enroll them from a class detail screen, then add a grade.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppTheme.warningColor),
                );
              }
              return DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: inputDecoration.copyWith(hintText: 'Select Class'),
                items: classes
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
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
              loading: () => const TVProgressIndicator(),
              error: (e, _) => Text(
                postgrestErrorMessage(e),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return Text(
                    'No subjects assigned to this class. Assign subjects from the class screen first.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  );
                }
                final validIds = assignments
                    .map((a) => a.classSubjectId)
                    .toSet();
                final current =
                    _selectedClassSubjectId != null &&
                        validIds.contains(_selectedClassSubjectId)
                    ? _selectedClassSubjectId
                    : null;
                return DropdownButtonFormField<String>(
                  value: current,
                  decoration: inputDecoration.copyWith(
                    hintText: 'Select Subject',
                  ),
                  items: assignments
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.classSubjectId,
                          child: Text(a.subject.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedClassSubjectId = v),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Choose a subject' : null,
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TVTextField(
                  controller: _value,
                  label: 'Grade Value',
                  keyboardType: TextInputType.number,
                  validator: (v) => _requiredInt(v, 'Value'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TVTextField(
                  controller: _period,
                  label: 'Period (e.g. 1 for Q1)',
                  keyboardType: TextInputType.number,
                  validator: (v) => _requiredInt(v, 'Period'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TVTextField(controller: _note, label: 'Note (Optional)', maxLines: 3),
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
                label: 'Save Grade',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving ? null : _submitForNew,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, Grade grade) {
    _seedFromGrade(grade);

    final ctxLabel = [
      if (grade.className != null) grade.className,
      if (grade.subjectName != null) grade.subjectName,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ctxLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ctxLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TVTextField(
                  controller: _value,
                  label: 'Grade Value',
                  keyboardType: TextInputType.number,
                  validator: (v) => _requiredInt(v, 'Value'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TVTextField(
                  controller: _period,
                  label: 'Period',
                  keyboardType: TextInputType.number,
                  validator: (v) => _requiredInt(v, 'Period'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TVTextField(controller: _note, label: 'Note (Optional)', maxLines: 3),
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
                label: 'Save Changes',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving
                    ? null
                    : () => _submitForEdit(widget.gradeId!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Grade' : 'Record Grade';
    final subtitle = _isEdit
        ? 'Update details for this grade.'
        : 'Log a new grade for this student.';

    Widget body;
    if (!_isEdit) {
      body = _buildNewForm(context);
    } else {
      final detailAsync = ref.watch(gradeDetailProvider(widget.gradeId!));
      body = detailAsync.when(
        loading: () => const TVProgressIndicator(),
        error: (e, _) => Center(
          child: Text(
            postgrestErrorMessage(e),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (grade) {
          if (grade == null) {
            return const Center(child: Text('Grade not found.'));
          }
          if (grade.studentId != widget.studentId) {
            return const Center(
              child: Text('Grade does not belong to this student.'),
            );
          }
          return _buildEditForm(context, grade);
        },
      );
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
}
