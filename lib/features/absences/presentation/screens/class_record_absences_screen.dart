import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Pick a subject, date, and which enrolled students were absent; save many rows at once.
class ClassRecordAbsencesScreen extends ConsumerStatefulWidget {
  const ClassRecordAbsencesScreen({required this.classId, super.key});

  final String classId;

  @override
  ConsumerState<ClassRecordAbsencesScreen> createState() =>
      _ClassRecordAbsencesScreenState();
}

class _ClassRecordAbsencesScreenState
    extends ConsumerState<ClassRecordAbsencesScreen> {
  final _reason = TextEditingController();
  final _selected = <String>{};

  String? _classSubjectId;
  DateTime? _date;
  bool _saving = false;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date ?? _dateOnly(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _date = _dateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (_classSubjectId == null || _classSubjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a subject.')),
      );
      return;
    }
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a date.')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one absent student.')),
      );
      return;
    }

    final assignments =
        await ref.read(classSubjectAssignmentsProvider(widget.classId).future);
    if (!mounted) return;
    final validIds = assignments.map((a) => a.classSubjectId).toSet();
    if (!validIds.contains(_classSubjectId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That subject is not on this class.')),
      );
      return;
    }

    final enrolled = await ref.read(
      classEnrolledStudentsProvider(widget.classId).future,
    );
    if (!mounted) return;
    final allowed = enrolled.map((s) => s.id).toSet();
    final studentIds = _selected.intersection(allowed).toList();
    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected students are no longer in this class.'),
        ),
      );
      return;
    }

    final teacher = await ref.read(currentTeacherProvider.future);
    if (!mounted) return;
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(absencesRepositoryProvider).createBulkForClass(
            teacherId: teacher.id,
            classId: widget.classId,
            classSubjectId: _classSubjectId!,
            absenceDate: _date!,
            studentIds: studentIds,
            reason: _reason.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${studentIds.length} absence${studentIds.length == 1 ? '' : 's'} recorded.',
            ),
          ),
        );
        context.pop();
      }
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
    final classAsync = ref.watch(classDetailProvider(widget.classId));
    final assignmentsAsync =
        ref.watch(classSubjectAssignmentsProvider(widget.classId));
    final enrolledAsync =
        ref.watch(classEnrolledStudentsProvider(widget.classId));

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: classAsync.maybeWhen(
          data: (c) => Text(c == null ? 'Class' : '${c.name} · Absences'),
          orElse: () => const Text('Record absences'),
        ),
      ),
      body: classAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
          ),
        ),
        data: (schoolClass) {
          if (schoolClass == null) {
            return const Center(child: Text('Class not found.'));
          }
          return enrolledAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
              ),
            ),
            data: (students) {
              return assignmentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      postgrestErrorMessage(e),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (List<ClassSubjectAssignment> assignments) {
                  if (assignments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Assign at least one subject to this class before '
                          'recording absences.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (students.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Enroll students in this class first.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final validCs =
                      assignments.map((a) => a.classSubjectId).toSet();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            DropdownButtonFormField<String>(
                              value: _classSubjectId != null &&
                                      validCs.contains(_classSubjectId)
                                  ? _classSubjectId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Subject (this class period)',
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
                                  setState(() => _classSubjectId = v),
                            ),
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
                                      _date != null
                                          ? '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'
                                          : 'Select',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    onPressed: _pickDate,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _reason,
                              label: 'Reason (optional, same for all)',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Text(
                                  'Absent students',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _selected
                                      ..clear()
                                      ..addAll(students.map((s) => s.id));
                                  }),
                                  child: const Text('All'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(_selected.clear),
                                  child: const Text('None'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...students.map(
                              (s) => CheckboxListTile(
                                value: _selected.contains(s.id),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(s.id);
                                    } else {
                                      _selected.remove(s.id);
                                    }
                                  });
                                },
                                secondary: CircleAvatar(
                                  child: Text(
                                    s.fullName.isNotEmpty
                                        ? s.fullName[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(s.fullName),
                                subtitle: s.email != null
                                    ? Text(s.email!)
                                    : null,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppButton(
                          label: 'Save absences',
                          onPressed: _save,
                          isLoading: _saving,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
