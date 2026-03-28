import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class ClassSubjectGradesScreen extends ConsumerWidget {
  const ClassSubjectGradesScreen({
    required this.classId,
    required this.classSubjectId,
    super.key,
  });

  final String classId;
  final String classSubjectId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Grade g,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete grade'),
        content: const Text('Remove this grade entry?'),
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
      final repo = ref.read(gradesRepositoryProvider);
      final teacher = await ref.read(currentTeacherProvider.future);
      if (teacher == null) return;
      await repo.delete(teacherId: teacher.id, gradeId: g.id);
      ref.invalidate(classSubjectGradesProvider(classSubjectId));
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
    final gradesAsync = ref.watch(classSubjectGradesProvider(classSubjectId));
    final assignmentsAsync = ref.watch(
      classSubjectAssignmentsProvider(classId),
    );

    final subjectLabel = assignmentsAsync.maybeWhen(
      data: (list) {
        for (final a in list) {
          if (a.classSubjectId == classSubjectId) return a.subject.name;
        }
        return 'Subject';
      },
      orElse: () => 'Subject',
    );

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subjectLabel),
            Text(
              'Grades',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Period & final grades',
            onPressed: () => context.push(
              AppRoutes.classSubjectFinalGradesHubPath(classId, classSubjectId),
            ),
          ),
        ],
      ),
      body: gradesAsync.when(
        loading: () => const TVSkeletonList(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
                FilledButton(
                  onPressed: () => ref.invalidate(
                    classSubjectGradesProvider(classSubjectId),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (grades) => grades.isEmpty
            ? Center(
                child: Text(
                  'No grades for this subject yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: grades.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final g = grades[i];
                  final name = g.studentName ?? 'Student';
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(
                      'Period ${g.period} · Value ${g.gradeValue}'
                      '${g.note != null && g.note!.isNotEmpty ? ' · ${g.note}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => context.push(
                            AppRoutes.studentGradeEditPath(g.studentId, g.id),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, ref, g),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
