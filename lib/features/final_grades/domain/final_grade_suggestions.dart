/// Averages from raw `grades` rows (period 1–3 only). All nullable when no marks.
class FinalGradeSuggestions {
  const FinalGradeSuggestions({
    this.period1,
    this.period2,
    this.period3,
    this.finalMark,
  });

  final int? period1;
  final int? period2;
  final int? period3;

  /// Average of non-null period suggestions, rounded. Independent of DB `final_grades`.
  final int? finalMark;
}
