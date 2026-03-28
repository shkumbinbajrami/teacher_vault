import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/class_subjects/data/class_subjects_repository.dart';
import 'package:teacher_vault/features/class_subjects/domain/class_subject_assignment.dart';
import 'package:teacher_vault/features/classes/data/class_students_repository.dart';
import 'package:teacher_vault/features/classes/data/classes_repository.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final classesRepositoryProvider = Provider<ClassesRepository>(
  (ref) => ClassesRepository(ref.watch(supabaseProvider)),
);

final classStudentsRepositoryProvider = Provider<ClassStudentsRepository>(
  (ref) => ClassStudentsRepository(ref.watch(supabaseProvider)),
);

final classSubjectsRepositoryProvider = Provider<ClassSubjectsRepository>(
  (ref) => ClassSubjectsRepository(ref.watch(supabaseProvider)),
);

final classesListProvider = FutureProvider<List<SchoolClass>>((ref) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(classesRepositoryProvider).listByTeacherId(teacher.id);
});

final classDetailProvider =
    FutureProvider.family<SchoolClass?, String>((ref, classId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref.watch(classesRepositoryProvider).fetchById(
        teacherId: teacher.id,
        classId: classId,
      );
});

final classEnrolledStudentsProvider =
    FutureProvider.family<List<Student>, String>((ref, classId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(classStudentsRepositoryProvider).listEnrolledStudents(
        teacherId: teacher.id,
        classId: classId,
      );
});

/// Classes this student is enrolled in.
final studentClassesProvider =
    FutureProvider.family<List<SchoolClass>, String>((ref, studentId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(classStudentsRepositoryProvider).listClassesForStudent(
        teacherId: teacher.id,
        studentId: studentId,
      );
});

/// All class–subject assignments for classes this student is enrolled in.
final studentClassSubjectAssignmentsProvider =
    FutureProvider.family<List<ClassSubjectAssignment>, String>(
        (ref, studentId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  final classes =
      await ref.watch(studentClassesProvider(studentId).future);
  final repo = ref.watch(classSubjectsRepositoryProvider);
  final out = <ClassSubjectAssignment>[];
  for (final c in classes) {
    final a = await repo.listAssignmentsForClass(
      teacherId: teacher.id,
      classId: c.id,
    );
    out.addAll(a);
  }
  out.sort((a, b) => a.subject.name.compareTo(b.subject.name));
  return out;
});

/// `class_subjects` rows for a class (includes id for grades).
final classSubjectAssignmentsProvider =
    FutureProvider.family<List<ClassSubjectAssignment>, String>(
  (ref, classId) async {
    final teacher = await ref.watch(currentTeacherProvider.future);
    if (teacher == null) return [];
    return ref.watch(classSubjectsRepositoryProvider).listAssignmentsForClass(
          teacherId: teacher.id,
          classId: classId,
        );
  },
);
