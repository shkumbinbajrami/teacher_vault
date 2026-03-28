import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

Future<void> _openFinalGradesPicker(
  BuildContext context,
  WidgetRef ref,
  String studentId,
) async {
  try {
    final grades = await ref.read(studentGradesProvider(studentId).future);
    if (!context.mounted) return;
    final map = <String, String>{};
    for (final g in grades) {
      final label = [
        if (g.className != null) g.className,
        if (g.subjectName != null) g.subjectName,
      ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
      map[g.classSubjectId] = label.isEmpty ? 'Class subject' : label;
    }
    if (map.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one grade for a class–subject to open period & final averages.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Choose class–subject',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ...map.entries.map(
                  (e) => ListTile(
                    title: Text(e.value),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(
                        AppRoutes.studentFinalGradeFormPath(studentId, e.key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
    }
  }
}

class StudentGradesScreen extends ConsumerWidget {
  const StudentGradesScreen({required this.studentId, super.key});

  final String studentId;

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
      ref.invalidate(studentGradesProvider(studentId));
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
    final async = ref.watch(studentGradesProvider(studentId));

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Grades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Period & final grades',
            onPressed: () => _openFinalGradesPicker(context, ref, studentId),
          ),
        ],
      ),
      body: async.when(
        loading: () => const TVSkeletonList(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(studentGradesProvider(studentId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (grades) => grades.isEmpty
            ? Center(
                child: Text(
                  'No grades yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: grades.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final g = grades[i];
                  final ctxLabel = [
                    if (g.className != null) g.className,
                    if (g.subjectName != null) g.subjectName,
                  ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
                  return ListTile(
                    title: Text(ctxLabel.isEmpty ? 'Grade' : ctxLabel),
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
                            AppRoutes.studentGradeEditPath(studentId, g.id),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.studentGradeNewPath(studentId)),
        icon: const Icon(Icons.add),
        label: const Text('Add grade'),
      ),
    );
  }
}
