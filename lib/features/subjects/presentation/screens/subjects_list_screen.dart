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
import 'package:teacher_vault/features/subjects/domain/subject.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';

class SubjectsListScreen extends ConsumerStatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  ConsumerState<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends ConsumerState<SubjectsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Subject> _applySearch(List<Subject> subjects) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return subjects;
    return subjects.where((s) {
      if (s.name.toLowerCase().contains(q)) return true;
      final d = s.description?.toLowerCase() ?? '';
      return d.contains(q);
    }).toList();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(subjectsListProvider);
    ref.invalidate(subjectClassCountsProvider);
    await Future.wait([
      ref.read(subjectsListProvider.future),
      ref.read(subjectClassCountsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsListProvider);
    final countsAsync = ref.watch(subjectClassCountsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TVPageHeader(
                title: 'Subjects',
                subtitle: 'Manage all courses and subjects you teach.',
                primaryActionLabel: 'Add Subject',
                onPrimaryAction: () => context.push(AppRoutes.subjectsNew),
              ),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search subjects by name or description',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: subjectsAsync.when(
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
                          onPressed: _onRefresh,
                        ),
                      ],
                    ),
                  ),
                  data: (subjects) {
                    final classCounts = countsAsync.maybeWhen(
                      data: (m) => m,
                      orElse: () => <String, int>{},
                    );
                    final countsLoading = countsAsync.isLoading;
                    final countsError = countsAsync.hasError;

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: _buildListBody(
                        context,
                        subjects: subjects,
                        filtered: _applySearch(subjects),
                        classCounts: classCounts,
                        countsLoading: countsLoading,
                        countsError: countsError,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context, {
    required List<Subject> subjects,
    required List<Subject> filtered,
    required Map<String, int> classCounts,
    required bool countsLoading,
    required bool countsError,
  }) {
    if (subjects.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TVEmptyState(
            title: 'No subjects yet',
            message: 'Create a subject to start assigning it to classes.',
            icon: Icons.menu_book_rounded,
            actionLabel: 'Add First Subject',
            onAction: () => context.push(AppRoutes.subjectsNew),
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          TVEmptyState(
            title: 'No matched subjects',
            message: 'Try adjusting your search query.',
            icon: Icons.search_off_rounded,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 64),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = filtered[index];
        final n = classCounts[s.id] ?? 0;
        return _SubjectRowCard(
          subject: s,
          distinctClassCount: n,
          classCountLoading: countsLoading && !countsError,
          countsError: countsError,
        );
      },
    );
  }
}

class _SubjectRowCard extends StatelessWidget {
  const _SubjectRowCard({
    required this.subject,
    required this.distinctClassCount,
    required this.classCountLoading,
    required this.countsError,
  });

  final Subject subject;
  final int distinctClassCount;
  final bool classCountLoading;
  final bool countsError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = subject;

    String classesLine;
    if (countsError) {
      classesLine = 'Could not load class usage';
    } else if (classCountLoading) {
      classesLine = 'Loading classes...';
    } else if (distinctClassCount == 0) {
      classesLine = 'Unassigned';
    } else if (distinctClassCount == 1) {
      classesLine = 'Used in 1 class';
    } else {
      classesLine = 'Used in $distinctClassCount classes';
    }

    return TVCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.subjectDetailPath(s.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppTheme
                    .secondaryColor, // Secondary is not defined in AppTheme directly. Will use Warning/Secondary logic.
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!s.isActive) ...[
                        const SizedBox(width: 8),
                        const TVBadge(
                          label: 'Inactive',
                          type: TVBadgeType.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (s.description != null &&
                      s.description!.trim().isNotEmpty) ...[
                    Text(
                      s.description!.trim(),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        classesLine,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
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
    );
  }
}
