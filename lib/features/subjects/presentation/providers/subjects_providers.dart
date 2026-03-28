import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/subjects/data/subjects_repository.dart';
import 'package:teacher_vault/features/subjects/domain/subject.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final subjectsRepositoryProvider = Provider<SubjectsRepository>(
  (ref) => SubjectsRepository(ref.watch(supabaseProvider)),
);

final subjectsListProvider = FutureProvider<List<Subject>>((ref) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return [];
  return ref.watch(subjectsRepositoryProvider).listByTeacherId(teacher.id);
});

/// Subject id → number of distinct classes using that subject.
final subjectClassCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return {};
  return ref.watch(classSubjectsRepositoryProvider).distinctClassCountBySubjectForTeacher(
        teacher.id,
      );
});

final subjectDetailProvider =
    FutureProvider.family<Subject?, String>((ref, subjectId) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref.watch(subjectsRepositoryProvider).fetchById(
        teacherId: teacher.id,
        subjectId: subjectId,
      );
});
