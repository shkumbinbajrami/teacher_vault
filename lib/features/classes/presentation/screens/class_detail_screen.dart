import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/utils/user_error_message.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({required this.classId, super.key});

  final String classId;

  Future<void> _confirmDeleteClass(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class'),
        content: const Text(
          'This removes the class and may remove subject links or grades depending on your database rules.',
        ),
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
      await ref.read(classesRepositoryProvider).delete(
            teacherId: teacher.id,
            classId: classId,
          );
      ref.invalidate(classesListProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showEnrollSheet(BuildContext parentContext, WidgetRef ref) async {
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    final allStudents = await ref.read(studentsListProvider.future);
    final enrolled = await ref.read(classEnrolledStudentsProvider(classId).future);
    final enrolledIds = enrolled.map((e) => e.id).toSet();
    final available = allStudents.where((s) => !enrolledIds.contains(s.id)).toList();

    if (!parentContext.mounted) return;

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.45;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add student',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'All your students are already in this class, or you have no students yet.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    height: h,
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final s = available[i];
                        return ListTile(
                          title: Text(s.fullName),
                          subtitle: s.email != null ? Text(s.email!) : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(classStudentsRepositoryProvider)
                                  .enroll(
                                    teacherId: teacher.id,
                                    classId: classId,
                                    studentId: s.id,
                                  );
                              ref.invalidate(
                                classEnrolledStudentsProvider(classId),
                              );
                            } catch (e) {
                              if (parentContext.mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text(userErrorMessage(e)),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAssignSubjectSheet(
    BuildContext parentContext,
    WidgetRef ref,
  ) async {
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    final allSubjects = await ref.read(subjectsListProvider.future);
    final assigned =
        await ref.read(classSubjectAssignmentsProvider(classId).future);
    final assignedIds = assigned.map((e) => e.subject.id).toSet();
    final available =
        allSubjects.where((s) => !assignedIds.contains(s.id)).toList();

    if (!parentContext.mounted) return;

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.45;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign subject',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'All subjects are already assigned, or you have no subjects yet.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    height: h,
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final s = available[i];
                        return ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(s.name),
                          subtitle: s.description != null &&
                                  s.description!.isNotEmpty
                              ? Text(
                                  s.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(classSubjectsRepositoryProvider)
                                  .assignSubject(
                                    teacherId: teacher.id,
                                    classId: classId,
                                    subjectId: s.id,
                                  );
                              ref.invalidate(
                                classSubjectAssignmentsProvider(classId),
                              );
                            } catch (e) {
                              if (parentContext.mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text(userErrorMessage(e)),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove subject from class'),
        content: Text(
          'Remove "${subject.name}" from this class? Grades for this '
          'class–subject may be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(classSubjectsRepositoryProvider).removeSubject(
            classId: classId,
            subjectId: subject.id,
          );
      ref.invalidate(classSubjectAssignmentsProvider(classId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmRemoveStudent(
    BuildContext context,
    WidgetRef ref,
    Student student,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from class'),
        content: Text(
          'Remove ${student.fullName} from this class?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(classStudentsRepositoryProvider).removeStudent(
            classId: classId,
            studentId: student.id,
          );
      ref.invalidate(classEnrolledStudentsProvider(classId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classDetailProvider(classId));
    final assignmentsAsync = ref.watch(classSubjectAssignmentsProvider(classId));
    final enrolledAsync = ref.watch(classEnrolledStudentsProvider(classId));

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Class'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_busy_outlined),
            tooltip: 'Record absences',
            onPressed: () =>
                context.push(AppRoutes.classRecordAbsencesPath(classId)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.classEditPath(classId)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteClass(context, ref),
          ),
        ],
      ),
      body: classAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(classDetailProvider(classId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Class not found.'));
          }

          final scheme = Theme.of(context).colorScheme;

          const twoColumnMinWidth = 840.0;

          Widget subjectsSection() {
            return _FlatSection(
              title: 'Subjects in class',
              headerActions: [
                TextButton.icon(
                  onPressed: () => _showAssignSubjectSheet(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              child: assignmentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(postgrestErrorMessage(e)),
                ),
                data: (List<ClassSubjectAssignment> assignments) {
                  if (assignments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No subjects yet. Tap Add to assign.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < assignments.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _SubjectRow(
                          assignment: assignments[i],
                          onGrades: () => context.push(
                            AppRoutes.classSubjectGradesPath(
                              classId,
                              assignments[i].classSubjectId,
                            ),
                          ),
                          onRemove: () => _confirmRemoveSubject(
                            context,
                            ref,
                            assignments[i].subject,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          }

          Widget studentsSection() {
            return _FlatSection(
              title: 'Students in class',
              headerActions: [
                IconButton(
                  icon: const Icon(Icons.event_busy_outlined),
                  tooltip: 'Record absences',
                  onPressed: () => context.push(
                    AppRoutes.classRecordAbsencesPath(classId),
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showEnrollSheet(context, ref),
                  icon: const Icon(Icons.person_add_outlined, size: 20),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              child: enrolledAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(postgrestErrorMessage(e)),
                ),
                data: (students) {
                  if (students.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No students yet. Tap Add to enroll.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < students.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _StudentRow(
                          student: students[i],
                          onRemove: () => _confirmRemoveStudent(
                            context,
                            ref,
                            students[i],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _ClassProfileHeaderCard(
                schoolClass: c,
                subjectsCount: assignmentsAsync.maybeWhen(
                  data: (list) => list.length,
                  orElse: () => null,
                ),
                studentsCount: enrolledAsync.maybeWhen(
                  data: (list) => list.length,
                  orElse: () => null,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= twoColumnMinWidth) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: subjectsSection()),
                        const SizedBox(width: 16),
                        Expanded(child: studentsSection()),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      subjectsSection(),
                      const SizedBox(height: 16),
                      studentsSection(),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClassProfileHeaderCard extends StatelessWidget {
  const _ClassProfileHeaderCard({
    required this.schoolClass,
    this.subjectsCount,
    this.studentsCount,
  });

  final SchoolClass schoolClass;
  final int? subjectsCount;
  final int? studentsCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;

    final iconBox = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Icon(
        Icons.meeting_room_outlined,
        color: scheme.primary,
        size: 26,
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          c.schoolYear,
          style: textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final stats = _HeaderQuickStats(
      scheme: scheme,
      textTheme: textTheme,
      studentsCount: studentsCount,
      subjectsCount: subjectsCount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(width: 14),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    stats,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      iconBox,
                      const SizedBox(width: 14),
                      Expanded(child: titleBlock),
                    ],
                  ),
                  const SizedBox(height: 14),
                  stats,
                ],
              );
            },
          ),
          if (c.description != null && c.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              c.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.isActive
                  ? scheme.tertiaryContainer.withValues(alpha: 0.5)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Text(
              c.isActive ? 'Active' : 'Inactive',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.isActive
                    ? scheme.onTertiaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderQuickStats extends StatelessWidget {
  const _HeaderQuickStats({
    required this.scheme,
    required this.textTheme,
    this.studentsCount,
    this.subjectsCount,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final int? studentsCount;
  final int? subjectsCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      children: [
        _HeaderStatCell(
          scheme: scheme,
          textTheme: textTheme,
          icon: Icons.groups_outlined,
          value: studentsCount,
          label: 'Students',
        ),
        _HeaderStatCell(
          scheme: scheme,
          textTheme: textTheme,
          icon: Icons.menu_book_outlined,
          value: subjectsCount,
          label: 'Subjects',
        ),
      ],
    );
  }
}

class _HeaderStatCell extends StatelessWidget {
  const _HeaderStatCell({
    required this.scheme,
    required this.textTheme,
    required this.icon,
    required this.value,
    required this.label,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final IconData icon;
  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '—' : '${value!}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                display,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlatSection extends StatelessWidget {
  const _FlatSection({
    required this.title,
    required this.headerActions,
    required this.child,
  });

  final String title;
  final List<Widget> headerActions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              ...headerActions,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.assignment,
    required this.onGrades,
    required this.onRemove,
  });

  final ClassSubjectAssignment assignment;
  final VoidCallback onGrades;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sub = assignment.subject;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sub.description != null &&
                      sub.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: onGrades,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Grades'),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              tooltip: 'Remove from class',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.onRemove,
  });

  final Student student;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = student;
    final initial = s.fullName.isNotEmpty
        ? s.fullName[0].toUpperCase()
        : '?';

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Container(
                width: 40,
                height: 40,
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.fullName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.email != null && s.email!.isNotEmpty)
                    Text(
                      s.email!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              tooltip: 'Remove from class',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
