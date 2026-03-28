import 'package:teacher_vault/features/subjects/domain/subject.dart';

/// Row from `class_subjects` with resolved [subject].
class ClassSubjectAssignment {
  const ClassSubjectAssignment({
    required this.classSubjectId,
    required this.classId,
    required this.subject,
  });

  final String classSubjectId;
  final String classId;
  final Subject subject;
}
