import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StudentAbsencesScreen extends ConsumerStatefulWidget {
  const StudentAbsencesScreen({required this.studentId, super.key});

  final String studentId;

  @override
  ConsumerState<StudentAbsencesScreen> createState() =>
      _StudentAbsencesScreenState();
}

class _StudentAbsencesScreenState extends ConsumerState<StudentAbsencesScreen> {
  late AbsenceListQuery _query;

  @override
  void initState() {
    super.initState();
    _query = AbsenceListQuery(studentId: widget.studentId);
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _query.fromDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      final d = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _query = AbsenceListQuery(
          studentId: widget.studentId,
          fromDate: d,
          toDate: _query.toDate,
          classSubjectId: _query.classSubjectId,
        );
      });
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _query.toDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      final d = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _query = AbsenceListQuery(
          studentId: widget.studentId,
          fromDate: _query.fromDate,
          toDate: d,
          classSubjectId: _query.classSubjectId,
        );
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _query = AbsenceListQuery(studentId: widget.studentId);
    });
  }

  Future<void> _confirmDelete(BuildContext context, Absence a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete absence'),
        content: const Text('Remove this absence record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final teacher = await ref.read(currentTeacherProvider.future);
      if (teacher == null) return;
      await ref
          .read(absencesRepositoryProvider)
          .delete(teacherId: teacher.id, absenceId: a.id);
      ref.invalidate(studentAbsencesProvider(_query));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentAbsencesProvider(_query));
    final assignmentsAsync = ref.watch(
      studentClassSubjectAssignmentsProvider(widget.studentId),
    );

    return Scaffold(
      appBar: TeacherVaultAppBar(title: const Text('Absences')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: assignmentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (List<ClassSubjectAssignment> list) {
                return DropdownButtonFormField<String?>(
                  value: _query.classSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject / class period',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All subjects'),
                    ),
                    ...list.map(
                      (a) => DropdownMenuItem(
                        value: a.classSubjectId,
                        child: Text(a.subject.name),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _query = AbsenceListQuery(
                        studentId: widget.studentId,
                        fromDate: _query.fromDate,
                        toDate: _query.toDate,
                        classSubjectId: v,
                      );
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _query.fromDate != null
                        ? 'From ${_fmtDate(_query.fromDate!)}'
                        : 'From date',
                  ),
                  onPressed: _pickFrom,
                ),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(
                    _query.toDate != null
                        ? 'To ${_fmtDate(_query.toDate!)}'
                        : 'To date',
                  ),
                  onPressed: _pickTo,
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const TVSkeletonList(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        postgrestErrorMessage(e),
                        textAlign: TextAlign.center,
                      ),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(studentAbsencesProvider(_query)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (List<Absence> list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No absences match your filters.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    final ctxLabel =
                        [
                              if (a.className != null) a.className,
                              if (a.subjectName != null) a.subjectName,
                            ]
                            .whereType<String>()
                            .where((e) => e.isNotEmpty)
                            .join(' · ');
                    return ListTile(
                      title: Text(
                        ctxLabel.isEmpty ? 'Class subject' : ctxLabel,
                      ),
                      subtitle: Text(
                        '${_fmtDate(a.absenceDate)}'
                        '${a.reason != null && a.reason!.isNotEmpty ? ' — ${a.reason}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await context.push(
                                AppRoutes.studentAbsenceEditPath(
                                  widget.studentId,
                                  a.id,
                                ),
                              );
                              if (mounted) {
                                ref.invalidate(studentAbsencesProvider(_query));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, a),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.studentAbsenceNewPath(widget.studentId));
          if (mounted) ref.invalidate(studentAbsencesProvider(_query));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add absence'),
      ),
    );
  }
}
