import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(currentTeacherProvider);
    // final client = ref.watch(supabaseProvider);
    // final email = client.auth.currentUser?.email ?? '';

    final greetingName = teacherAsync.maybeWhen(
      data: (t) {
        final n = t?.fullName?.trim();
        return (n != null && n.isNotEmpty) ? n : null;
      },
      orElse: () => null,
    );

    final classesAsync = ref.watch(classesListProvider);
    final studentsAsync = ref.watch(studentsListProvider);
    final subjectsAsync = ref.watch(subjectsListProvider);

    final textTheme = Theme.of(context).textTheme;
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const padH = 32.0;

          // Responsive grid counts
          final statCrossAxis = maxW < 600
              ? 1
              : maxW < 900
              ? 3
              : 3;
          final navCrossAxis = maxW < 600
              ? 1
              : maxW < 900
              ? 2
              : 3;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(padH, 32, padH, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Region
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            today,
                            style: textTheme.labelLarge?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            greetingName != null
                                ? 'Good morning, $greetingName'
                                : 'Dashboard',
                            style: textTheme.displaySmall?.copyWith(
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Core Metrics
                Text(
                  'Overview',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _StatsGrid(
                  crossAxisCount: statCrossAxis,
                  classesValue: _statLength(
                    classesAsync,
                    textTheme,
                    AppTheme.primaryColor,
                  ),
                  studentsValue: _statLength(
                    studentsAsync,
                    textTheme,
                    AppTheme.successColor,
                  ),
                  subjectsValue: _statLength(
                    subjectsAsync,
                    textTheme,
                    AppTheme.warningColor,
                  ),
                ),

                const SizedBox(height: 48),

                // Management & Navigation
                Text(
                  'Manage Hub',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _NavCardGrid(
                  crossAxisCount: navCrossAxis,
                  onClasses: () => context.push(AppRoutes.classes),
                  onStudents: () => context.push(AppRoutes.students),
                  onSubjects: () => context.push(AppRoutes.subjects),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _statLength<T>(
  AsyncValue<List<T>> async,
  TextTheme textTheme,
  Color accentColor,
) {
  return async.when(
    data: (list) => Text(
      '${list.length}',
      style: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: AppTheme.textPrimaryColor,
      ),
    ),
    loading: () => const TVSkeleton(
      width: 40,
      height: 32,
    ),
    error: (_, __) => Text(
      '—',
      style: textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppTheme.errorColor,
      ),
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.crossAxisCount,
    required this.classesValue,
    required this.studentsValue,
    required this.subjectsValue,
  });

  final int crossAxisCount;
  final Widget classesValue;
  final Widget studentsValue;
  final Widget subjectsValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 16.0;
        final w = constraints.maxWidth;
        final count = crossAxisCount;
        final tileW = (w - spacing * (count - 1)) / count;
        final thirdStatW = count == 2 ? w : tileW;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: tileW,
              child: _StatCard(
                label: 'Total Classes',
                icon: Icons.meeting_room_rounded,
                iconColor: AppTheme.primaryColor,
                valueWidget: classesValue,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _StatCard(
                label: 'Enrolled Students',
                icon: Icons.groups_rounded,
                iconColor: AppTheme.successColor,
                valueWidget: studentsValue,
              ),
            ),
            SizedBox(
              width: thirdStatW,
              child: _StatCard(
                label: 'Active Subjects',
                icon: Icons.menu_book_rounded,
                iconColor: AppTheme.warningColor,
                valueWidget: subjectsValue,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.valueWidget,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Widget valueWidget;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    valueWidget,
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCardGrid extends StatelessWidget {
  const _NavCardGrid({
    required this.crossAxisCount,
    required this.onClasses,
    required this.onStudents,
    required this.onSubjects,
  });

  final int crossAxisCount;
  final VoidCallback onClasses;
  final VoidCallback onStudents;
  final VoidCallback onSubjects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 16.0;
        final w = constraints.maxWidth;
        final count = crossAxisCount;
        final tileW = (w - spacing * (count - 1)) / count;
        final thirdNavW = count == 2 ? w : tileW;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: tileW,
              child: _NavCard(
                title: 'Classes',
                subtitle: 'Rooms, cohorts, and enrollments.',
                icon: Icons.meeting_room_outlined,
                onTap: onClasses,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _NavCard(
                title: 'Students',
                subtitle: 'Profiles, membership, and grades.',
                icon: Icons.school_outlined,
                onTap: onStudents,
              ),
            ),
            SizedBox(
              width: thirdNavW,
              child: _NavCard(
                title: 'Subjects',
                subtitle: 'Courses, assignments, and analytics.',
                icon: Icons.menu_book_outlined,
                onTap: onSubjects,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outlineColor),
              ),
              child: Icon(icon, color: AppTheme.textPrimaryColor, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Manage',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
