import 'package:teacher_vault/features/final_grades/domain/final_grade.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_suggestions.dart';

class FinalGradeDraft {
  const FinalGradeDraft({this.saved, required this.suggestions});

  final FinalGrade? saved;
  final FinalGradeSuggestions suggestions;
}
