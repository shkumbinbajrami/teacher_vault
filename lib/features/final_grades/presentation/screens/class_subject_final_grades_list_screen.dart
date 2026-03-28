import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/final_grades/presentation/providers/final_grades_providers.dart';

/// Enrolled students for [classId]; open [FinalGradeFormScreen] per student for [classSubjectId].
class ClassSubjectFinalGradesListScreen extends ConsumerWidget {
  const ClassSubjectFinalGradesListScreen({
    required this.classId,
    required this.classSubjectId,
    super.key,
  });

  final String classId;
  final String classSubjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledAsync = ref.watch(classEnrolledStudentsProvider(classId));
    final assignmentsAsync = ref.watch(classSubjectAssignmentsProvider(classId));

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
        title: Text('$subjectLabel — Final grades'),
      ),
      body: enrolledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(classEnrolledStudentsProvider(classId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Text(
                'No students in this class. Enroll students first.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: students.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = students[i];
              final params = FinalGradeDraftParams(
                studentId: s.id,
                classSubjectId: classSubjectId,
              );
              final savedAsync = ref.watch(finalGradeSavedProvider(params));
              final hasFinal = savedAsync.maybeWhen(
                data: (g) => g != null,
                orElse: () => false,
              );
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(s.fullName),
                subtitle: Text(
                  hasFinal ? 'Saved final row — tap to review or edit' : 'Tap to review suggestions and save',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  AppRoutes.classSubjectFinalGradeFormPath(
                    classId,
                    classSubjectId,
                    s.id,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
