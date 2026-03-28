import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_badge.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
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
          'This may fail if the subject is used in classes. Remove assignments first.',
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
          .read(subjectsRepositoryProvider)
          .delete(teacherId: teacher.id, subjectId: subjectId);
      ref.invalidate(subjectsListProvider);
      ref.invalidate(subjectProfileSnapshotProvider(subjectId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
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
                        context.push(AppRoutes.subjectEditPath(subjectId)),
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
                        onPressed: () {
                          ref.invalidate(subjectDetailProvider(subjectId));
                          ref.invalidate(
                            subjectProfileSnapshotProvider(subjectId),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                data: (subject) {
                  if (subject == null) {
                    return const Center(child: Text('Subject not found.'));
                  }

                  final profileAsync = ref.watch(
                    subjectProfileSnapshotProvider(subjectId),
                  );
                  final teacherAsync = ref.watch(currentTeacherProvider);

                  return _SubjectProfileBody(
                    subject: subject,
                    profileAsync: profileAsync,
                    teacherAsync: teacherAsync,
                    onRefresh: () => _onRefresh(ref),
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
        final wide = constraints.maxWidth >= 900;
        final pad = const EdgeInsets.fromLTRB(32, 0, 32, 64);

        Widget scroll(Widget child) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              padding: pad,
              physics: const AlwaysScrollableScrollPhysics(),
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
                const SizedBox(height: 24),
                const TVProgressIndicator(),
              ],
            ),
          ),
          error: (e, _) => scroll(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 24),
                Text(
                  postgrestErrorMessage(e),
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ],
            ),
          ),
          data: (snap) {
            final stats = _SubjectStatsGrid(snap: snap);
            final classesCard = _ClassesUsingSubjectSection(
              links: snap.classLinks,
            );

            if (wide) {
              return scroll(
                Column(
                  children: [
                    header,
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: classesCard),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              stats,
                              const SizedBox(height: 24),
                              _SubjectAboutCard(
                                linkCount: snap.classLinks.length,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  const SizedBox(height: 24),
                  stats,
                  const SizedBox(height: 24),
                  classesCard,
                  const SizedBox(height: 24),
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
  const _SubjectHeaderCard({required this.subject, required this.teacher});

  final Subject subject;
  final Teacher? teacher;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                  Icons.menu_book_outlined,
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
                            subject.name,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (!subject.isActive)
                          const TVBadge(
                            label: 'Inactive',
                            type: TVBadgeType.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      teacher?.fullName?.trim().isNotEmpty == true
                          ? 'Subject in your workspace · ${teacher!.fullName!.trim()}'
                          : 'Subject in your workspace',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subject.description != null &&
              subject.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              subject.description!.trim(),
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
              const Icon(
                Icons.badge_outlined,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  subject.id,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy subject ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: subject.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject ID copied')),
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

class _SubjectStatsGrid extends StatelessWidget {
  const _SubjectStatsGrid({required this.snap});
  final SubjectProfileSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.meeting_room_outlined,
                color: AppTheme.primaryColor,
                value: '${snap.classLinks.length}',
                label: snap.classLinks.length == 1 ? 'Class' : 'Classes',
                hint: 'Using this subject',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.groups_outlined,
                color: AppTheme.secondaryColor,
                value: '${snap.distinctStudentCount}',
                label: snap.distinctStudentCount == 1 ? 'Student' : 'Students',
                hint: 'Enrolled across classes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.grade_outlined,
                color: AppTheme.successColor,
                value: '${snap.gradeEntryCount}',
                label: snap.gradeEntryCount == 1 ? 'Grade' : 'Grades',
                hint: 'Recorded entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.event_busy_outlined,
                color: AppTheme.errorColor,
                value: '${snap.absenceCount}',
                label: 'Absences',
                hint: 'Logged for subject',
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
    final textTheme = Theme.of(context).textTheme;
    return TVCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 16),
          Text(
            value,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
          const SizedBox(height: 4),
          Text(
            hint,
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ClassesUsingSubjectSection extends StatelessWidget {
  const _ClassesUsingSubjectSection({required this.links});
  final List<SubjectClassLink> links;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Classes Taught In',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a class or jump directly to the gradebook.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (links.isEmpty)
            const Text(
              'Not linked to any class yet.',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < links.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ClassSubjectLinkRow(link: links[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ClassSubjectLinkRow extends StatelessWidget {
  const _ClassSubjectLinkRow({required this.link});
  final SubjectClassLink link;

  @override
  Widget build(BuildContext context) {
    final c = link.schoolClass;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push(AppRoutes.classDetailPath(c.id)),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              c.schoolYear + (c.isActive ? '' : ' · Inactive'),
                              style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 13,
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
            ),
            const SizedBox(width: 12),
            TVSecondaryButton(
              label: 'Gradebook',
              icon: Icons.grade_outlined,
              onPressed: () => context.push(
                AppRoutes.classSubjectGradesPath(c.id, link.classSubjectId),
              ),
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
    final textTheme = Theme.of(context).textTheme;
    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'How this works',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            linkCount == 0
                ? 'Subjects are reusable labels. Link this one to a class to start using it.'
                : 'Assignments, grades, and absences are stored per assigned class. Each class maintains its distinct marks for this Subject.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
