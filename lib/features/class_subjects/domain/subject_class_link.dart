import 'package:teacher_vault/features/classes/domain/school_class.dart';

/// A [SchoolClass] that teaches this subject (`class_subjects` row).
class SubjectClassLink {
  const SubjectClassLink({
    required this.classSubjectId,
    required this.schoolClass,
  });

  final String classSubjectId;
  final SchoolClass schoolClass;
}
