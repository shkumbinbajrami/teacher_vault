import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Roll-up counts for the signed-in teacher (from `classes`, `students`, `subjects`, `class_subjects`).
class TeacherWorkspaceSummary {
  const TeacherWorkspaceSummary({
    required this.classCount,
    required this.studentCount,
    required this.subjectCount,
    required this.classSubjectAssignmentCount,
  });

  final int classCount;
  final int studentCount;
  final int subjectCount;

  /// Rows in `class_subjects` for this teacher’s classes (subject–class links).
  final int classSubjectAssignmentCount;
}

final teacherWorkspaceSummaryProvider =
    FutureProvider<TeacherWorkspaceSummary>((ref) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) {
    return const TeacherWorkspaceSummary(
      classCount: 0,
      studentCount: 0,
      subjectCount: 0,
      classSubjectAssignmentCount: 0,
    );
  }
  final tid = teacher.id;
  final classes = await ref.read(classesRepositoryProvider).listByTeacherId(tid);
  final students =
      await ref.read(studentsRepositoryProvider).listByTeacherId(tid);
  final subjects =
      await ref.read(subjectsRepositoryProvider).listByTeacherId(tid);
  final links = await ref
      .read(classSubjectsRepositoryProvider)
      .countAssignmentsForTeacher(tid);
  return TeacherWorkspaceSummary(
    classCount: classes.length,
    studentCount: students.length,
    subjectCount: subjects.length,
    classSubjectAssignmentCount: links,
  );
});
