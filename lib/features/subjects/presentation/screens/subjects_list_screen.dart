import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
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

  static InputBorder _searchBorder(ColorScheme scheme) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsListProvider);
    final countsAsync = ref.watch(subjectClassCountsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Subjects'),
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  postgrestErrorMessage(e),
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton(
                onPressed: () {
                  ref.invalidate(subjectsListProvider);
                  ref.invalidate(subjectClassCountsProvider);
                },
                child: const Text('Retry'),
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: scheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search by name or description',
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          maxHeight: 44,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        border: _searchBorder(scheme),
                        enabledBorder: _searchBorder(scheme),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _buildListBody(
                    context,
                    subjects: subjects,
                    filtered: _applySearch(subjects),
                    classCounts: classCounts,
                    countsLoading: countsLoading,
                    countsError: countsError,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.subjectsNew),
        icon: const Icon(Icons.add),
        label: const Text('Add subject'),
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
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No subjects yet. Tap + to add one.')),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
        children: [
          Center(
            child: Text(
              'No subjects match your search.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = subject;

    String classesLine;
    if (countsError) {
      classesLine = 'Could not load class usage';
    } else if (classCountLoading) {
      classesLine = 'Loading classes…';
    } else if (distinctClassCount == 0) {
      classesLine = 'Not used in any class yet';
    } else if (distinctClassCount == 1) {
      classesLine = 'Used in 1 class';
    } else {
      classesLine = 'Used in $distinctClassCount classes';
    }

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.subjectDetailPath(s.id)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: scheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!s.isActive) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: const Text('Inactive'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            classesLine,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (s.description != null &&
                        s.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        s.description!.trim(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
    );
  }
}
