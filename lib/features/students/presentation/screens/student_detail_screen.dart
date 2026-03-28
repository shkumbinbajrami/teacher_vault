import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({required this.studentId, super.key});

  final String studentId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student'),
        content: const Text(
          'This cannot be undone. Class enrollments may be affected.',
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
          .read(studentsRepositoryProvider)
          .delete(teacherId: teacher.id, studentId: studentId);
      ref.invalidate(studentsListProvider);
      if (context.mounted) context.pop();
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
    final async = ref.watch(studentDetailProvider(studentId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
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
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onPressed: () =>
                        context.push(AppRoutes.studentEditPath(studentId)),
                  ),
                  const SizedBox(width: 8),
                  TVSecondaryButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
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
                            ref.invalidate(studentDetailProvider(studentId)),
                      ),
                    ],
                  ),
                ),
                data: (student) {
                  if (student == null) {
                    return const Center(child: Text('Student not found.'));
                  }
                  return _StudentProfileBody(student: student);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentProfileBody extends ConsumerWidget {
  const _StudentProfileBody({required this.student});

  final Student student;

  static double? _avgGrade(List<Grade> grades) {
    if (grades.isEmpty) return null;
    final sum = grades.fold<int>(0, (a, g) => a + g.gradeValue);
    return sum / grades.length;
  }

  static List<Grade> _recentGrades(List<Grade> grades, int n) {
    final copy = [...grades];
    copy.sort((a, b) {
      final p = a.period.compareTo(b.period);
      if (p != 0) return p;
      return a.id.compareTo(b.id);
    });
    if (copy.length <= n) return copy.reversed.toList();
    return copy.reversed.take(n).toList();
  }

  static Map<String, String> _classNames(List<SchoolClass> classes) {
    return {for (final c in classes) c.id: c.name};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(studentClassesProvider(student.id));
    final assignmentsAsync = ref.watch(
      studentClassSubjectAssignmentsProvider(student.id),
    );
    final gradesAsync = ref.watch(studentGradesProvider(student.id));
    final absencesAsync = ref.watch(
      studentAbsencesProvider(AbsenceListQuery(studentId: student.id)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = const EdgeInsets.fromLTRB(32, 0, 32, 64);
        final wide = constraints.maxWidth >= 900;

        final header = _ProfileHeaderCard(student: student);
        final stats = _buildStatsRow(
          context,
          classesAsync: classesAsync,
          gradesAsync: gradesAsync,
          absencesAsync: absencesAsync,
        );
        final classesSection = _buildClassesSection(context, classesAsync);
        final subjectsSection = _buildSubjectsSection(
          context,
          assignmentsAsync,
          classesAsync,
        );

        if (wide) {
          return SingleChildScrollView(
            padding: pad,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 20),
                      classesSection,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stats,
                      const SizedBox(height: 20),
                      subjectsSection,
                      const SizedBox(height: 20),
                      _buildRecentGradesCard(context, gradesAsync, student.id),
                    ],
                  ),
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
              const SizedBox(height: 20),
              stats,
              const SizedBox(height: 20),
              classesSection,
              const SizedBox(height: 20),
              subjectsSection,
              const SizedBox(height: 20),
              _buildRecentGradesCard(context, gradesAsync, student.id),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(
    BuildContext context, {
    required AsyncValue<List<SchoolClass>> classesAsync,
    required AsyncValue<List<Grade>> gradesAsync,
    required AsyncValue<List<Absence>> absencesAsync,
  }) {
    final classesCount = classesAsync.valueOrNull?.length ?? 0;
    final grades = gradesAsync.valueOrNull ?? [];
    final avg = _avgGrade(grades);
    final absences = absencesAsync.valueOrNull ?? <Absence>[];

    String gradesSubtitle = gradesAsync.isLoading
        ? '...'
        : (grades.isEmpty
              ? 'No grades yet'
              : 'Avg ${avg!.toStringAsFixed(1)} · ${grades.length} total');

    String absencesSubtitle = absencesAsync.isLoading
        ? '...'
        : (absences.isEmpty ? 'None logged' : '${absences.length} records');

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.meeting_room_outlined,
            iconColor: AppTheme.primaryColor,
            value: classesAsync.isLoading ? '...' : '$classesCount',
            label: classesCount == 1 ? 'Class' : 'Classes',
            subtitle: 'Enrolled',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.grade_outlined,
            iconColor: AppTheme.successColor,
            value: gradesAsync.isLoading
                ? '...'
                : (grades.isEmpty ? '—' : '${grades.length}'),
            label: 'Grades',
            subtitle: gradesSubtitle,
            onTap: () => context.push(AppRoutes.studentGradesPath(student.id)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.event_busy_outlined,
            iconColor: AppTheme.errorColor,
            value: absencesAsync.isLoading ? '...' : '${absences.length}',
            label: 'Absences',
            subtitle: absencesSubtitle,
            onTap: () =>
                context.push(AppRoutes.studentAbsencesPath(student.id)),
          ),
        ),
      ],
    );
  }

  Widget _buildClassesSection(
    BuildContext context,
    AsyncValue<List<SchoolClass>> async,
  ) {
    return _SectionCard(
      title: 'Current Enrollments',
      subtitle: 'Classes this student belongs to',
      child: async.when(
        loading: () => const Center(
          child: TVProgressIndicator(),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: const TextStyle(color: AppTheme.errorColor),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Not enrolled in any class yet. Add them from a class page.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              for (final c in classes) ...[
                if (c != classes.first) const SizedBox(height: 12),
                _ClassEnrollmentRow(schoolClass: c),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubjectsSection(
    BuildContext context,
    AsyncValue<List<ClassSubjectAssignment>> assignmentsAsync,
    AsyncValue<List<SchoolClass>> classesAsync,
  ) {
    final classNames = _classNames(classesAsync.valueOrNull ?? []);
    final textTheme = Theme.of(context).textTheme;

    return _SectionCard(
      title: 'Active Subjects',
      subtitle: 'Courses linked through enrolled classes',
      child: assignmentsAsync.when(
        loading: () => const Center(
          child: TVProgressIndicator(),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: const TextStyle(color: AppTheme.errorColor),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'No subjects available. Assign subjects to their classes first.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              for (var i = 0; i < assignments.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignments[i].subject.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            classNames[assignments[i].classId] ?? 'Class',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentGradesCard(
    BuildContext context,
    AsyncValue<List<Grade>> gradesAsync,
    String studentId,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return _SectionCard(
      title: 'Recent Grades',
      subtitle: 'Latest entries by period',
      child: gradesAsync.when(
        loading: () => const Center(
          child: TVProgressIndicator(),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: const TextStyle(color: AppTheme.errorColor),
        ),
        data: (grades) {
          final recent = _recentGrades(grades, 5);
          if (recent.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'No grades recorded yet.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            );
          }
          return Column(
            children: [
              const SizedBox(height: 12),
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0)
                  const Divider(height: 24, color: AppTheme.outlineColor),
                InkWell(
                  onTap: () =>
                      context.push(AppRoutes.studentGradesPath(studentId)),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${recent[i].gradeValue}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recent[i].subjectName?.trim().isNotEmpty == true
                                  ? recent[i].subjectName!
                                  : 'Subject',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              [
                                if (recent[i].className != null &&
                                    recent[i].className!.isNotEmpty)
                                  recent[i].className,
                                'Pd ${recent[i].period}',
                              ].whereType<String>().join(' · '),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.outlineColor,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClassEnrollmentRow extends StatelessWidget {
  const _ClassEnrollmentRow({required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.classDetailPath(c.id)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      c.schoolYear + (c.isActive ? '' : ' · Inactive'),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.outlineColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = student;
    final initial = s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?';

    Widget avatar;
    final url = s.avatarUrl;
    const size = 96.0;
    if (url != null && url.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(url, width: size, height: size, fit: BoxFit.cover),
      );
    } else {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      s.fullName,
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (s.email != null && s.email!.trim().isNotEmpty)
                                ? s.email!.trim()
                                : 'No email on file',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontStyle:
                                  (s.email != null &&
                                      s.email!.trim().isNotEmpty)
                                  ? null
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppTheme.outlineColor),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  s.id,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy student ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: s.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student ID copied')),
                  );
                },
                icon: const Icon(
                  Icons.copy_outlined,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
