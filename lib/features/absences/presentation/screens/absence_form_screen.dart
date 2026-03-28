import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Create ([absenceId] == null) or edit an absence for [studentId].
class AbsenceFormScreen extends ConsumerStatefulWidget {
  const AbsenceFormScreen({
    required this.studentId,
    super.key,
    this.absenceId,
  });

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

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a date.')),
      );
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(absencesRepositoryProvider).create(
            teacherId: teacher.id,
            studentId: widget.studentId,
            classSubjectId: _selectedClassSubjectId!,
            absenceDate: _selectedDate!,
            reason: _reason.text,
          );
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

  Future<void> _submitEdit(String absenceId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedClassSubjectId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose subject and date.')),
      );
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(absencesRepositoryProvider).update(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormBody({
    required bool isEdit,
    Absence? existing,
  }) {
    final classesAsync = ref.watch(studentClassesProvider(widget.studentId));
    final assignmentsAsync = _selectedClassId != null
        ? ref.watch(classSubjectAssignmentsProvider(_selectedClassId!))
        : null;

    if (isEdit && existing != null) {
      // ignore: discarded_futures
      _seedFromAbsence(existing);
    }

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
                    'Enroll this student in a class first.',
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
                      'No subjects assigned to this class.',
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
                      labelText: 'Subject (class period)',
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
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Absence date',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Select a date',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _selectedDate != null
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _reason,
              label: 'Reason (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Save',
              onPressed: () {
                if (_isEdit) {
                  _submitEdit(widget.absenceId!);
                } else {
                  _submitNew();
                }
              },
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit absence' : 'Record absence';

    if (!_isEdit) {
      return Scaffold(
        appBar: TeacherVaultAppBar(title: Text(title)),
        body: _buildFormBody(isEdit: false, existing: null),
      );
    }

    final detailAsync = ref.watch(absenceDetailProvider(widget.absenceId!));
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
        data: (a) {
          if (a == null) {
            return const Center(child: Text('Absence not found.'));
          }
          if (a.studentId != widget.studentId) {
            return const Center(
              child: Text('This absence does not belong to this student.'),
            );
          }
          return _buildFormBody(isEdit: true, existing: a);
        },
      ),
    );
  }
}
