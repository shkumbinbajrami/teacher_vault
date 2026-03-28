import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/class_subjects/domain/subject_class_link.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subject_detail_providers.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/domain/teacher.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({required this.subjectId, super.key});

  final String subjectId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject'),
        content: const Text(
          'This may fail if the subject is used in classes (class_subjects).',
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
      await ref.read(subjectsRepositoryProvider).delete(
            teacherId: teacher.id,
            subjectId: subjectId,
          );
      ref.invalidate(subjectsListProvider);
      ref.invalidate(subjectProfileSnapshotProvider(subjectId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(subjectDetailProvider(subjectId));
    ref.invalidate(subjectProfileSnapshotProvider(subjectId));
    await Future.wait([
      ref.read(subjectDetailProvider(subjectId).future),
      ref.read(subjectProfileSnapshotProvider(subjectId).future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectDetailProvider(subjectId));

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Subject'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push(AppRoutes.subjectEditPath(subjectId)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
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
                  onPressed: () {
                    ref.invalidate(subjectDetailProvider(subjectId));
                    ref.invalidate(subjectProfileSnapshotProvider(subjectId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (subject) {
          if (subject == null) {
            return const Center(child: Text('Subject not found.'));
          }
          final profileAsync =
              ref.watch(subjectProfileSnapshotProvider(subjectId));
          final teacherAsync = ref.watch(currentTeacherProvider);

          return _SubjectProfileBody(
            subject: subject,
            profileAsync: profileAsync,
            teacherAsync: teacherAsync,
            onRefresh: () => _onRefresh(ref),
          );
        },
      ),
    );
  }
}

class _SubjectProfileBody extends StatelessWidget {
  const _SubjectProfileBody({
    required this.subject,
    required this.profileAsync,
    required this.teacherAsync,
    required this.onRefresh,
  });

  final Subject subject;
  final AsyncValue<SubjectProfileSnapshot> profileAsync;
  final AsyncValue<Teacher?> teacherAsync;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final bottom = 100.0;
        final pad = const EdgeInsets.fromLTRB(16, 12, 16, 0);

        Widget scroll(Widget child) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: pad.left,
                right: pad.right,
                top: pad.top,
                bottom: bottom,
              ),
              child: child,
            ),
          );
        }

        final header = _SubjectHeaderCard(
          subject: subject,
          teacher: teacherAsync.valueOrNull,
        );

        return profileAsync.when(
          loading: () => scroll(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          error: (e, _) => scroll(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                Text(
                  postgrestErrorMessage(e),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
          data: (snap) {
            final stats = _SubjectStatsGrid(snapshot: snap);
            final classesCard = _ClassesUsingSubjectSection(
              links: snap.classLinks,
            );

            if (wide) {
              return scroll(
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
                          classesCard,
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
                          _SubjectAboutCard(
                            linkCount: snap.classLinks.length,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return scroll(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 14),
                  stats,
                  const SizedBox(height: 14),
                  classesCard,
                  const SizedBox(height: 14),
                  _SubjectAboutCard(linkCount: snap.classLinks.length),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SubjectHeaderCard extends StatelessWidget {
  const _SubjectHeaderCard({
    required this.subject,
    required this.teacher,
  });

  final Subject subject;
  final Teacher? teacher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = subject;

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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: scheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(s.isActive ? 'Active' : 'Inactive'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        teacher?.fullName?.trim().isNotEmpty == true
                            ? 'Subject in your workspace · ${teacher!.fullName!.trim()}'
                            : 'Subject in your workspace',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.description != null && s.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                s.description!.trim(),
                style: textTheme.bodyLarge,
              ),
            ],
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
                  tooltip: 'Copy subject ID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: s.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subject ID copied')),
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

class _SubjectStatsGrid extends StatelessWidget {
  const _SubjectStatsGrid({required this.snapshot});

  final SubjectProfileSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    final classes = snap.classLinks.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.meeting_room_outlined,
                color: Theme.of(context).colorScheme.primary,
                value: '$classes',
                label: classes == 1 ? 'Class' : 'Classes',
                hint: 'Teaching this subject',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: Icons.groups_outlined,
                color: Theme.of(context).colorScheme.tertiary,
                value: '${snap.distinctStudentCount}',
                label: snap.distinctStudentCount == 1 ? 'Student' : 'Students',
                hint: 'Enrolled in those classes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.grade_outlined,
                color: Theme.of(context).colorScheme.primary,
                value: '${snap.gradeEntryCount}',
                label: snap.gradeEntryCount == 1 ? 'Grade' : 'Grades',
                hint: 'Recorded marks',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                icon: Icons.event_busy_outlined,
                color: Theme.of(context).colorScheme.error,
                value: '${snap.absenceCount}',
                label: 'Absences',
                hint: 'Logged for this subject',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
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
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassesUsingSubjectSection extends StatelessWidget {
  const _ClassesUsingSubjectSection({
    required this.links,
  });

  final List<SubjectClassLink> links;

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
              'Classes using this subject',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open a class or jump to its gradebook for this subject.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (links.isEmpty)
              Text(
                'Not linked to any class yet. Assign it from a class’s subjects.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < links.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ClassSubjectLinkRow(link: links[i]),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassSubjectLinkRow extends StatelessWidget {
  const _ClassSubjectLinkRow({required this.link});

  final SubjectClassLink link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = link.schoolClass;

    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push(AppRoutes.classDetailPath(c.id)),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room_outlined, color: scheme.primary),
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
                              c.schoolYear +
                                  (c.isActive ? '' : ' · Inactive'),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Grades for this class',
              onPressed: () {
                context.push(
                  AppRoutes.classSubjectGradesPath(
                    c.id,
                    link.classSubjectId,
                  ),
                );
              },
              icon: const Icon(Icons.grade_outlined),
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectAboutCard extends StatelessWidget {
  const _SubjectAboutCard({required this.linkCount});

  final int linkCount;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this fits in Teacher Vault',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              linkCount == 0
                  ? 'Subjects are reusable labels. Link this one to a class, then add students and record grades or absences per class–subject.'
                  : 'Students see this subject only in classes where it’s assigned. Grades and absences are stored per class–subject, so each class has its own marks for this subject.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
