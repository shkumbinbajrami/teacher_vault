import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/students/data/students_repository.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>(
  (ref) => StudentsRepository(ref.watch(supabaseProvider)),
);

final studentsListProvider = FutureProvider<List<Student>>((ref) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(studentsRepositoryProvider).listByTeacherId(teacher.id);
});

final studentDetailProvider = FutureProvider.family<Student?, String>((
  ref,
  studentId,
) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref
      .watch(studentsRepositoryProvider)
      .fetchById(teacherId: teacher.id, studentId: studentId);
});
