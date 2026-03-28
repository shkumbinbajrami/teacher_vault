import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/final_grades/data/final_grades_repository.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_draft.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final finalGradesRepositoryProvider = Provider<FinalGradesRepository>(
  (ref) => FinalGradesRepository(ref.watch(supabaseProvider)),
);

/// Parameters for loading draft state (saved row + computed suggestions from `grades`).
class FinalGradeDraftParams {
  const FinalGradeDraftParams({
    required this.studentId,
    required this.classSubjectId,
  });

  final String studentId;
  final String classSubjectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalGradeDraftParams &&
          other.studentId == studentId &&
          other.classSubjectId == classSubjectId;

  @override
  int get hashCode => Object.hash(studentId, classSubjectId);
}

final finalGradeDraftProvider =
    FutureProvider.family<FinalGradeDraft, FinalGradeDraftParams>((ref, p) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) {
    throw StateError('Not signed in.');
  }
  final repo = ref.watch(finalGradesRepositoryProvider);
  final saved = await repo.fetchForStudentSubject(
    teacherId: teacher.id,
    studentId: p.studentId,
    classSubjectId: p.classSubjectId,
  );
  final suggestions = await repo.computeSuggestionsFromGrades(
    teacherId: teacher.id,
    studentId: p.studentId,
    classSubjectId: p.classSubjectId,
  );
  return FinalGradeDraft(saved: saved, suggestions: suggestions);
});

final finalGradeSavedProvider =
    FutureProvider.family<FinalGrade?, FinalGradeDraftParams>((ref, p) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref.watch(finalGradesRepositoryProvider).fetchForStudentSubject(
        teacherId: teacher.id,
        studentId: p.studentId,
        classSubjectId: p.classSubjectId,
      );
});
