import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_vault/features/absences/presentation/providers/absences_providers.dart';
import 'package:teacher_vault/features/class_subjects/domain/subject_class_link.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/grades/presentation/providers/grades_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Aggregates class links and activity counts for a subject profile.
class SubjectProfileSnapshot {
  const SubjectProfileSnapshot({
    required this.classLinks,
    required this.gradeEntryCount,
    required this.absenceCount,
    required this.distinctStudentCount,
  });

  final List<SubjectClassLink> classLinks;
  final int gradeEntryCount;
  final int absenceCount;
  final int distinctStudentCount;
}

final subjectProfileSnapshotProvider =
    FutureProvider.family<SubjectProfileSnapshot, String>((
      ref,
      subjectId,
    ) async {
      final teacher = await ref.watch(currentTeacherProvider.future);
      if (teacher == null) {
        return const SubjectProfileSnapshot(
          classLinks: [],
          gradeEntryCount: 0,
          absenceCount: 0,
          distinctStudentCount: 0,
        );
      }

      final links = await ref
          .watch(classSubjectsRepositoryProvider)
          .listClassesUsingSubject(teacherId: teacher.id, subjectId: subjectId);
      final csIds = links.map((e) => e.classSubjectId).toList();
      final classIds = links.map((e) => e.schoolClass.id).toList();

      if (csIds.isEmpty) {
        return SubjectProfileSnapshot(
          classLinks: links,
          gradeEntryCount: 0,
          absenceCount: 0,
          distinctStudentCount: 0,
        );
      }

      final gradeEntryCount = await ref
          .read(gradesRepositoryProvider)
          .countForClassSubjectIds(
            teacherId: teacher.id,
            classSubjectIds: csIds,
          );
      final absenceCount = await ref
          .read(absencesRepositoryProvider)
          .countForClassSubjectIds(
            teacherId: teacher.id,
            classSubjectIds: csIds,
          );
      final distinctStudentCount = await ref
          .read(classStudentsRepositoryProvider)
          .distinctEnrolledStudentCountForClasses(classIds: classIds);

      return SubjectProfileSnapshot(
        classLinks: links,
        gradeEntryCount: gradeEntryCount,
        absenceCount: absenceCount,
        distinctStudentCount: distinctStudentCount,
      );
    });
