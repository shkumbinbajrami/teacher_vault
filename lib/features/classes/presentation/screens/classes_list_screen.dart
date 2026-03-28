import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';

class ClassesListScreen extends ConsumerWidget {
  const ClassesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classesListProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Classes'),
      ),
      body: async.when(
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
                onPressed: () => ref.invalidate(classesListProvider),
                child: const Text('Retry'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radius),
                                ),
                                child: Icon(
                                  Icons.meeting_room_outlined,
                                  color: scheme.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No classes yet',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a class to start organizing students and subjects.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: classes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.classesNew),
        icon: const Icon(Icons.add),
        label: const Text('Add class'),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.schoolClass,
    required this.onTap,
  });

  final SchoolClass schoolClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = schoolClass;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(
                  Icons.meeting_room_outlined,
                  color: scheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.schoolYear,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!c.isActive)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: const Text('Inactive'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    side: BorderSide(color: scheme.outlineVariant),
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
