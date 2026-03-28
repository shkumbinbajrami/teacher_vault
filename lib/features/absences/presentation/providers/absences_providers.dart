import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/absences/data/absences_repository.dart';
import 'package:teacher_vault/features/absences/domain/absence.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

final absencesRepositoryProvider = Provider<AbsencesRepository>(
  (ref) => AbsencesRepository(ref.watch(supabaseProvider)),
);

/// Filters for [studentAbsencesProvider]. All fields optional except [studentId].
class AbsenceListQuery {
  const AbsenceListQuery({
    required this.studentId,
    this.fromDate,
    this.toDate,
    this.classSubjectId,
  });

  final String studentId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? classSubjectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbsenceListQuery &&
          other.studentId == studentId &&
          other.fromDate == fromDate &&
          other.toDate == toDate &&
          other.classSubjectId == classSubjectId;

  @override
  int get hashCode => Object.hash(studentId, fromDate, toDate, classSubjectId);
}

final studentAbsencesProvider =
    FutureProvider.family<List<Absence>, AbsenceListQuery>((ref, q) async {
      final teacher = await ref.watch(currentTeacherProvider.future);
      if (teacher == null) return [];
      return ref
          .watch(absencesRepositoryProvider)
          .listForStudent(
            teacherId: teacher.id,
            studentId: q.studentId,
            fromDate: q.fromDate,
            toDate: q.toDate,
            classSubjectId: q.classSubjectId,
          );
    });

final absenceDetailProvider = FutureProvider.family<Absence?, String>((
  ref,
  absenceId,
) async {
  final teacher = await ref.watch(currentTeacherProvider.future);
  if (teacher == null) return null;
  return ref
      .watch(absencesRepositoryProvider)
      .fetchById(teacherId: teacher.id, absenceId: absenceId);
});
