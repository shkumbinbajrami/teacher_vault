import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_badge.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_empty_state.dart';
import 'package:teacher_vault/core/widgets/tv_page_header.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';

class ClassesListScreen extends ConsumerWidget {
  const ClassesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classesListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Background comes from Shell
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TVPageHeader(
                title: 'Classes',
                subtitle: 'Manage all your cohorts and rooms.',
                primaryActionLabel: 'Add Class',
                onPrimaryAction: () => context.push(AppRoutes.classesNew),
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
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                        const SizedBox(height: 16),
                        TVSecondaryButton(
                          label: 'Retry',
                          onPressed: () => ref.invalidate(classesListProvider),
                        ),
                      ],
                    ),
                  ),
                  data: (classes) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(classesListProvider);
                      await ref.read(classesListProvider.future);
                    },
                    child: classes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              TVEmptyState(
                                title: 'No classes found',
                                message:
                                    'Create a class to start organizing students and subjects.',
                                icon: Icons.meeting_room_outlined,
                                actionLabel: 'Add First Class',
                                onAction: () =>
                                    context.push(AppRoutes.classesNew),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 64),
                            itemCount: classes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final c = classes[index];
                              return _ClassCard(
                                schoolClass: c,
                                onTap: () => context.push(
                                  AppRoutes.classDetailPath(c.id),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.schoolClass, required this.onTap});

  final SchoolClass schoolClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;

    return TVCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.meeting_room_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.schoolYear,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!c.isActive)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: TVBadge(label: 'Inactive', type: TVBadgeType.warning),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.outlineColor,
            ),
          ],
        ),
      ),
    );
  }
}
