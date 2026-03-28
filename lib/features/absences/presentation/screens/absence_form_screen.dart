import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class AbsenceFormScreen extends ConsumerStatefulWidget {
  const AbsenceFormScreen({required this.studentId, super.key, this.absenceId});

  final String studentId;
  final String? absenceId;

  @override
  ConsumerState<AbsenceFormScreen> createState() => _AbsenceFormScreenState();
}

class _AbsenceFormScreenState extends ConsumerState<AbsenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  bool _saving = false;
  String? _selectedClassId;
  String? _selectedClassSubjectId;
  DateTime? _selectedDate;
  bool _seededEdit = false;

  bool get _isEdit => widget.absenceId != null;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      final n = DateTime.now();
      _selectedDate = DateTime(n.year, n.month, n.day);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? _dateOnly(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = _dateOnly(picked));
    }
  }

  Future<void> _seedFromAbsence(Absence a) async {
    if (_seededEdit) return;
    _seededEdit = true;
    final cid = await ref
        .read(classSubjectsRepositoryProvider)
        .classIdForAssignment(a.classSubjectId);
    if (!mounted) return;
    setState(() {
      _selectedClassId = cid;
      _selectedClassSubjectId = a.classSubjectId;
      _selectedDate = _dateOnly(a.absenceDate);
      _reason.text = a.reason ?? '';
    });
  }

  Future<void> _submitNew() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedClassSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a class and subject.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a date.')));
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(absencesRepositoryProvider)
          .create(
            teacherId: teacher.id,
            studentId: widget.studentId,
            classSubjectId: _selectedClassSubjectId!,
            absenceDate: _selectedDate!,
            reason: _reason.text,
          );
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

  Future<void> _submitEdit(String absenceId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedClassSubjectId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose actual subject and date.')),
      );
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(absencesRepositoryProvider)
          .update(
            teacherId: teacher.id,
            studentId: widget.studentId,
            absenceId: absenceId,
            classSubjectId: _selectedClassSubjectId!,
            absenceDate: _selectedDate!,
            reason: _reason.text,
          );
      ref.invalidate(absenceDetailProvider(absenceId));
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
    final title = _isEdit ? 'Edit Absence' : 'Record Absence';
    final subtitle = _isEdit
        ? 'Update details for this absence record.'
        : 'Log an absence for this student.';

    Widget body;
    if (!_isEdit) {
      body = _buildFormBody(isEdit: false, existing: null);
    } else {
      final detailAsync = ref.watch(absenceDetailProvider(widget.absenceId!));
      body = detailAsync.when(
        loading: () => const TVProgressIndicator(),
        error: (e, _) => Center(
          child: Text(
            postgrestErrorMessage(e),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (a) {
          if (a == null) return const Center(child: Text('Absence not found.'));
          if (a.studentId != widget.studentId) {
            return const Center(
              child: Text('This absence does not belong to this student.'),
            );
          }
          return _buildFormBody(isEdit: true, existing: a);
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

  Widget _buildFormBody({required bool isEdit, Absence? existing}) {
    final classesAsync = ref.watch(studentClassesProvider(widget.studentId));
    final assignmentsAsync = _selectedClassId != null
        ? ref.watch(classSubjectAssignmentsProvider(_selectedClassId!))
        : null;

    if (isEdit && existing != null) {
      // ignore: discarded_futures
      _seedFromAbsence(existing);
    }

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
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            data: (classes) {
              if (classes.isEmpty) {
                return Text(
                  'Enroll this student in a class first.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.warningColor,
                  ),
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
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return Text(
                    'No subjects assigned to this class.',
                    style: textTheme.bodyMedium?.copyWith(
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
          Text(
            'Date of Absence',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.outlineColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Select a date',
                      style: textTheme.bodyLarge?.copyWith(
                        color: _selectedDate != null
                            ? AppTheme.textPrimaryColor
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TVTextField(
            controller: _reason,
            label: 'Reason (Optional)',
            maxLines: 4,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TVSecondaryButton(
                label: 'Cancel',
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 16),
              TVPrimaryButton(
                label: isEdit ? 'Save Changes' : 'Record Absence',
                icon: Icons.event_busy_outlined,
                isLoading: _saving,
                onPressed: _saving
                    ? null
                    : () => isEdit
                          ? _submitEdit(widget.absenceId!)
                          : _submitNew(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
