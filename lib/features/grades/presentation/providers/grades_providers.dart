import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/grades/data/grades_repository.dart';
import 'package:teacher_vault/features/grades/domain/grade.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final gradesRepositoryProvider = Provider<GradesRepository>(
  (ref) => GradesRepository(ref.watch(supabaseProvider)),
);

final studentGradesProvider =
    FutureProvider.family<List<Grade>, String>((ref, studentId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(gradesRepositoryProvider).listForStudent(
        teacherId: teacher.id,
        studentId: studentId,
      );
});

final classSubjectGradesProvider =
    FutureProvider.family<List<Grade>, String>((ref, classSubjectId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(gradesRepositoryProvider).listForClassSubject(
        teacherId: teacher.id,
        classSubjectId: classSubjectId,
      );
});

final gradeDetailProvider =
    FutureProvider.family<Grade?, String>((ref, gradeId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref.watch(gradesRepositoryProvider).fetchById(
        teacherId: teacher.id,
        gradeId: gradeId,
      );
});
