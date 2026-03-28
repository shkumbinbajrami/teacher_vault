import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/utils/user_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_badge.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
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
          .read(classesRepositoryProvider)
          .delete(teacherId: teacher.id, classId: classId);
      ref.invalidate(classesListProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
      }
    }
  }

  Future<void> _showEnrollSheet(
    BuildContext parentContext,
    WidgetRef ref,
  ) async {
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    final allStudents = await ref.read(studentsListProvider.future);
    final enrolled = await ref.read(
      classEnrolledStudentsProvider(classId).future,
    );
    final enrolledIds = enrolled.map((e) => e.id).toSet();
    final available = allStudents
        .where((s) => !enrolledIds.contains(s.id))
        .toList();

    if (!parentContext.mounted) return;

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.6;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enroll Student',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
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
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = available[i];
                      return TVCard(
                        padding: EdgeInsets.zero,
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
                                SnackBar(content: Text(userErrorMessage(e))),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  s.fullName.isNotEmpty
                                      ? s.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (s.email != null)
                                      Text(
                                        s.email!,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
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
    final assigned = await ref.read(
      classSubjectAssignmentsProvider(classId).future,
    );
    final assignedIds = assigned.map((e) => e.subject.id).toSet();
    final available = allSubjects
        .where((s) => !assignedIds.contains(s.id))
        .toList();

    if (!parentContext.mounted) return;

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.6;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Assign Subject',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
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
                  child: ListView.separated(
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = available[i];
                      return TVCard(
                        padding: EdgeInsets.zero,
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
                                SnackBar(content: Text(userErrorMessage(e))),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (s.description != null &&
                                        s.description!.isNotEmpty)
                                      Text(
                                        s.description!,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
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
        title: const Text('Remove subject'),
        content: Text(
          'Remove "${subject.name}" from this class? Grades for this class-subject may be lost depending on constraints.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref
          .read(classSubjectsRepositoryProvider)
          .removeSubject(classId: classId, subjectId: subject.id);
      ref.invalidate(classSubjectAssignmentsProvider(classId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
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
        title: const Text('Remove student'),
        content: Text('Remove ${student.fullName} from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref
          .read(classStudentsRepositoryProvider)
          .removeStudent(classId: classId, studentId: student.id);
      ref.invalidate(classEnrolledStudentsProvider(classId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classDetailProvider(classId));
    final assignmentsAsync = ref.watch(
      classSubjectAssignmentsProvider(classId),
    );
    final enrolledAsync = ref.watch(classEnrolledStudentsProvider(classId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
              child: Row(
                children: [
                  TVSecondaryButton(
                    label: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  TVSecondaryButton(
                    label: 'Attendance',
                    icon: Icons.event_busy_outlined,
                    onPressed: () => context.push(
                      AppRoutes.classRecordAbsencesPath(classId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TVSecondaryButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onPressed: () =>
                        context.push(AppRoutes.classEditPath(classId)),
                  ),
                  const SizedBox(width: 8),
                  TVSecondaryButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    onPressed: () => _confirmDeleteClass(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: classAsync.when(
                loading: () => const TVSkeletonList(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        postgrestErrorMessage(e),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                      const SizedBox(height: 16),
                      TVSecondaryButton(
                        label: 'Retry',
                        onPressed: () =>
                            ref.invalidate(classDetailProvider(classId)),
                      ),
                    ],
                  ),
                ),
                data: (c) {
                  if (c == null) {
                    return const Center(child: Text('Class not found.'));
                  }

                  const twoColumnMinWidth = 1000.0;
                  final pad = const EdgeInsets.fromLTRB(32, 0, 32, 64);

                  Widget header = _ClassProfileHeaderCard(
                    schoolClass: c,
                    subjectsCount: assignmentsAsync.valueOrNull?.length,
                    studentsCount: enrolledAsync.valueOrNull?.length,
                  );

                  Widget subjectsSection() {
                    return _SectionCard(
                      title: 'Subjects Taught',
                      primaryActionLabel: 'Assign',
                      onPrimaryAction: () =>
                          _showAssignSubjectSheet(context, ref),
                      child: assignmentsAsync.when(
                        loading: () => const TVProgressIndicator(),
                        error: (e, _) => Text(
                          postgrestErrorMessage(e),
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                        data: (assignments) {
                          if (assignments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'No subjects assigned yet.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < assignments.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
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
                    return _SectionCard(
                      title: 'Enrolled Students',
                      primaryActionLabel: 'Enroll',
                      onPrimaryAction: () => _showEnrollSheet(context, ref),
                      child: enrolledAsync.when(
                        loading: () => const TVProgressIndicator(),
                        error: (e, _) => Text(
                          postgrestErrorMessage(e),
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                        data: (students) {
                          if (students.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'No students enrolled yet.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < students.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _StudentRow(
                                  student: students[i],
                                  onRemove: () => _confirmRemoveStudent(
                                    context,
                                    ref,
                                    students[i],
                                  ),
                                  onNavigate: () => context.push(
                                    AppRoutes.studentDetailPath(students[i].id),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= twoColumnMinWidth;

                      if (wide) {
                        return SingleChildScrollView(
                          padding: pad,
                          child: Column(
                            children: [
                              header,
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: subjectsSection()),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 5, child: studentsSection()),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: pad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const SizedBox(height: 24),
                            subjectsSection(),
                            const SizedBox(height: 24),
                            studentsSection(),
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
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;

    return TVCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: AppTheme.primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (!c.isActive)
                          const TVBadge(
                            label: 'Inactive',
                            type: TVBadgeType.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.schoolYear,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.description != null && c.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              c.description!.trim(),
              style: textTheme.bodyLarge?.copyWith(
                color: AppTheme.textPrimaryColor,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppTheme.outlineColor),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _HeaderStatBlock(
                  icon: Icons.groups_outlined,
                  value: studentsCount?.toString(),
                  label: 'Students Enrolled',
                  color: AppTheme.successColor,
                ),
              ),
              Expanded(
                child: _HeaderStatBlock(
                  icon: Icons.menu_book_outlined,
                  value: subjectsCount?.toString(),
                  label: 'Subjects Taught',
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStatBlock extends StatelessWidget {
  const _HeaderStatBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String? value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = value ?? '...';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              display,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.primaryActionLabel,
    this.onPrimaryAction,
    required this.child,
  });

  final String title;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (primaryActionLabel != null && onPrimaryAction != null)
                TVPrimaryButton(
                  label: primaryActionLabel!,
                  icon: Icons.add_rounded,
                  onPressed: onPrimaryAction,
                ),
            ],
          ),
          const SizedBox(height: 16),
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.subject.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (assignment.subject.description != null &&
                      assignment.subject.description!.isNotEmpty)
                    Text(
                      assignment.subject.description!,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TVSecondaryButton(
              label: 'Gradebook',
              icon: Icons.grade_outlined,
              onPressed: onGrades,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: AppTheme.errorColor,
              ),
              onPressed: onRemove,
              tooltip: 'Remove from class',
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
    required this.onNavigate,
  });

  final Student student;
  final VoidCallback onRemove;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onNavigate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                radius: 18,
                child: Text(
                  s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (s.email != null)
                      Text(
                        s.email!,
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppTheme.errorColor,
                ),
                onPressed: onRemove,
                tooltip: 'Remove from class',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
