import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final teacher = await ref.read(currentTeacherProvider.future);
      if (teacher == null) return;
      await ref.read(studentsRepositoryProvider).delete(
            teacherId: teacher.id,
            studentId: studentId,
          );
      ref.invalidate(studentsListProvider);
      if (context.mounted) context.pop();
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
    final async = ref.watch(studentDetailProvider(studentId));

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              context.push(AppRoutes.studentEditPath(studentId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: async.when(
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
                  onPressed: () =>
                      ref.invalidate(studentDetailProvider(studentId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          return _StudentProfileBody(student: student);
        },
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
    final assignmentsAsync =
        ref.watch(studentClassSubjectAssignmentsProvider(student.id));
    final gradesAsync = ref.watch(studentGradesProvider(student.id));
    final absencesAsync = ref.watch(
      studentAbsencesProvider(AbsenceListQuery(studentId: student.id)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final bottomInset = 100.0;
        final pad = const EdgeInsets.fromLTRB(16, 12, 16, 0);

        Widget scrollable(Widget child) => SingleChildScrollView(
              padding: EdgeInsets.only(
                left: pad.left,
                right: pad.right,
                top: pad.top,
                bottom: bottomInset,
              ),
              child: child,
            );

        final header = _ProfileHeaderCard(student: student);
        final stats = _buildStatsRow(
          context,
          classesAsync: classesAsync,
          gradesAsync: gradesAsync,
          absencesAsync: absencesAsync,
        );
        final classesSection = _buildClassesSection(context, classesAsync);
        final subjectsSection =
            _buildSubjectsSection(context, assignmentsAsync, classesAsync);

        if (wide) {
          return scrollable(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 14),
                      classesSection,
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stats,
                      const SizedBox(height: 14),
                      subjectsSection,
                      const SizedBox(height: 14),
                      _buildRecentGradesCard(
                        context,
                        gradesAsync,
                        student.id,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return scrollable(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              stats,
              const SizedBox(height: 14),
              classesSection,
              const SizedBox(height: 14),
              subjectsSection,
              const SizedBox(height: 14),
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
    final scheme = Theme.of(context).colorScheme;

    final classesCount = classesAsync.valueOrNull?.length ?? 0;
    final grades = gradesAsync.valueOrNull ?? [];
    final avg = _avgGrade(grades);
    final absences = absencesAsync.valueOrNull ?? <Absence>[];

    String gradesSubtitle;
    if (gradesAsync.isLoading) {
      gradesSubtitle = '…';
    } else if (grades.isEmpty) {
      gradesSubtitle = 'No grades yet';
    } else {
      gradesSubtitle =
          'Avg ${avg!.toStringAsFixed(1)} · ${grades.length} total';
    }

    String absencesSubtitle;
    if (absencesAsync.isLoading) {
      absencesSubtitle = '…';
    } else if (absences.isEmpty) {
      absencesSubtitle = 'None logged';
    } else {
      absencesSubtitle = '${absences.length} record${absences.length == 1 ? '' : 's'}';
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.meeting_room_outlined,
            iconColor: scheme.primary,
            value: classesAsync.isLoading ? '…' : '$classesCount',
            label: classesCount == 1 ? 'Class' : 'Classes',
            subtitle: 'Enrolled',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.grade_outlined,
            iconColor: scheme.tertiary,
            value: gradesAsync.isLoading
                ? '…'
                : (grades.isEmpty ? '—' : '${grades.length}'),
            label: 'Grades',
            subtitle: gradesSubtitle,
            onTap: () =>
                context.push(AppRoutes.studentGradesPath(student.id)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.event_busy_outlined,
            iconColor: scheme.error,
            value: absencesAsync.isLoading ? '…' : '${absences.length}',
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
      title: 'Classes',
      subtitle: 'Where this student is enrolled',
      child: async.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Text(
              'Not enrolled in any class yet. Add them from a class page.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in classes) ...[
                if (c != classes.first) const SizedBox(height: 8),
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

    return _SectionCard(
      title: 'Subjects',
      subtitle: 'Courses linked through their classes',
      child: assignmentsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Text(
              'No subjects yet. Assign subjects to the student’s classes first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          }
          final lines = assignments
              .map((a) {
                final cn = classNames[a.classId] ?? 'Class';
                return '${a.subject.name} · $cn';
              })
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lines[i],
                        style: Theme.of(context).textTheme.bodyMedium,
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
    return _SectionCard(
      title: 'Recent grades',
      subtitle: 'Latest entries (by period)',
      child: gradesAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Text(
          postgrestErrorMessage(e),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (grades) {
          final recent = _recentGrades(grades, 5);
          if (recent.isEmpty) {
            return Text(
              'No grades recorded yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                InkWell(
                  onTap: () =>
                      context.push(AppRoutes.studentGradesPath(studentId)),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius),
                          ),
                          child: Text(
                            '${recent[i].gradeValue}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recent[i].subjectName?.trim().isNotEmpty ==
                                        true
                                    ? recent[i].subjectName!
                                    : 'Subject',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                [
                                  if (recent[i].className != null &&
                                      recent[i].className!.isNotEmpty)
                                    recent[i].className,
                                  'Period ${recent[i].period}',
                                ].whereType<String>().join(' · '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ],
                    ),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.classDetailPath(c.id)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.schoolYear + (c.isActive ? '' : ' · Inactive'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = student;
    final initial =
        s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?';

    Widget avatar;
    final url = s.avatarUrl;
    const r = 40.0;
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(radius: r, backgroundImage: NetworkImage(url));
    } else {
      avatar = CircleAvatar(
        radius: r,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.primary,
        child: Text(initial, style: textTheme.headlineSmall),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.fullName,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (s.email != null && s.email!.trim().isNotEmpty)
                                  ? s.email!.trim()
                                  : 'No email on file',
                              style: textTheme.bodyMedium?.copyWith(
                                color: (s.email != null &&
                                        s.email!.trim().isNotEmpty)
                                    ? null
                                    : scheme.onSurfaceVariant,
                                fontStyle: (s.email != null &&
                                        s.email!.trim().isNotEmpty)
                                    ? null
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    s.id,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: body,
      ),
    );
  }
}
