import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/features/auth/presentation/providers/auth_repository_provider.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(currentTeacherProvider);
    final client = ref.watch(supabaseProvider);
    final email = client.auth.currentUser?.email ?? 'Signed in';

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

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final teacher = teacherAsync.maybeWhen(data: (t) => t, orElse: () => null);
    final avatarUrl = teacher?.avatarUrl?.trim();
    final nameForInitial = teacherAsync.maybeWhen(
      data: (t) {
        final n = t?.fullName?.trim();
        if (n != null && n.isNotEmpty) return n;
        final at = email.indexOf('@');
        if (at > 0) return email.substring(0, at);
        return 'Teacher';
      },
      orElse: () => 'Teacher',
    );

    return Scaffold(
      appBar: TeacherVaultAppBar.dashboard(
        onProfile: () => context.push(AppRoutes.profile),
        onSignOut: () => ref.read(authRepositoryProvider).signOut(),
        profileAvatarUrl:
            (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
        profileNameForInitial: nameForInitial,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const padH = 20.0;
          final statCrossAxis = maxW < 520
              ? 1
              : maxW < 840
                  ? 2
                  : 3;
          final navCrossAxis = maxW < 640 ? 1 : maxW < 960 ? 2 : 3;

          return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(padH, 24, padH, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      greetingName != null ? 'Hello, $greetingName' : 'Welcome back',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Overview',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatsGrid(
                      crossAxisCount: statCrossAxis,
                      scheme: scheme,
                      textTheme: textTheme,
                      classesValue: _statLength(classesAsync, scheme, textTheme),
                      studentsValue:
                          _statLength(studentsAsync, scheme, textTheme),
                      subjectsValue:
                          _statLength(subjectsAsync, scheme, textTheme),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Manage',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NavCardGrid(
                      crossAxisCount: navCrossAxis,
                      scheme: scheme,
                      textTheme: textTheme,
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
  ColorScheme scheme,
  TextTheme textTheme,
) {
  return async.when(
    data: (list) => Text(
      '${list.length}',
      style: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: scheme.onSurface,
      ),
    ),
    loading: () => SizedBox(
      height: 28,
      width: 28,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.primary,
        ),
      ),
    ),
    error: (_, __) => Text(
      '—',
      style: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.error,
      ),
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.crossAxisCount,
    required this.scheme,
    required this.textTheme,
    required this.classesValue,
    required this.studentsValue,
    required this.subjectsValue,
  });

  final int crossAxisCount;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final Widget classesValue;
  final Widget studentsValue;
  final Widget subjectsValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
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
                label: 'Classes',
                icon: Icons.meeting_room_outlined,
                iconColor: scheme.primary,
                iconBackground: scheme.primaryContainer,
                valueWidget: classesValue,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _StatCard(
                label: 'Students',
                icon: Icons.groups_outlined,
                iconColor: scheme.tertiary,
                iconBackground: scheme.tertiaryContainer,
                valueWidget: studentsValue,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ),
            SizedBox(
              width: thirdStatW,
              child: _StatCard(
                label: 'Subjects',
                icon: Icons.menu_book_outlined,
                iconColor: scheme.secondary,
                iconBackground: scheme.secondaryContainer,
                valueWidget: subjectsValue,
                scheme: scheme,
                textTheme: textTheme,
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
    required this.iconBackground,
    required this.valueWidget,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Widget valueWidget;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCardGrid extends StatelessWidget {
  const _NavCardGrid({
    required this.crossAxisCount,
    required this.scheme,
    required this.textTheme,
    required this.onClasses,
    required this.onStudents,
    required this.onSubjects,
  });

  final int crossAxisCount;
  final ColorScheme scheme;
  final TextTheme textTheme;
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
                subtitle: 'Rooms, cohorts, and enrollments',
                icon: Icons.meeting_room_outlined,
                accent: scheme.primary,
                accentContainer: scheme.primaryContainer,
                onTap: onClasses,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _NavCard(
                title: 'Students',
                subtitle: 'Profiles and class membership',
                icon: Icons.school_outlined,
                accent: scheme.tertiary,
                accentContainer: scheme.tertiaryContainer,
                onTap: onStudents,
                scheme: scheme,
                textTheme: textTheme,
              ),
            ),
            SizedBox(
              width: thirdNavW,
              child: _NavCard(
                title: 'Subjects',
                subtitle: 'Courses you teach',
                icon: Icons.menu_book_outlined,
                accent: scheme.secondary,
                accentContainer: scheme.secondaryContainer,
                onTap: onSubjects,
                scheme: scheme,
                textTheme: textTheme,
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
    required this.accent,
    required this.accentContainer,
    required this.onTap,
    required this.scheme,
    required this.textTheme,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentContainer;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            color: scheme.surfaceContainerLow,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: 18),
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
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
