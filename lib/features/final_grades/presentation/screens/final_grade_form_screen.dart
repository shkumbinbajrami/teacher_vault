import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_draft.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_suggestions.dart';
import 'package:teacher_vault/features/final_grades/presentation/providers/final_grades_providers.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

/// Review averages suggested from [grades], edit freely, then save to `final_grades` (never auto-saves).
class FinalGradeFormScreen extends ConsumerStatefulWidget {
  const FinalGradeFormScreen({
    required this.studentId,
    required this.classSubjectId,
    super.key,
    this.classId,
  });

  final String studentId;
  final String classSubjectId;

  /// When opened from class flows; optional subtitle / back stack only.
  final String? classId;

  @override
  ConsumerState<FinalGradeFormScreen> createState() =>
      _FinalGradeFormScreenState();
}

class _FinalGradeFormScreenState extends ConsumerState<FinalGradeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  final _final = TextEditingController();

  bool _saving = false;
  Object? _seededForDraft;

  FinalGradeDraftParams get _params => FinalGradeDraftParams(
        studentId: widget.studentId,
        classSubjectId: widget.classSubjectId,
      );

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    _p3.dispose();
    _final.dispose();
    super.dispose();
  }

  String? _optionalInt(String? v, String label) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null) return '$label must be a whole number';
    if (n < 0) return '$label cannot be negative';
    return null;
  }

  int? _parseOptional(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  void _applyToControllers(FinalGradeSuggestions s) {
    _p1.text = s.period1 != null ? '${s.period1}' : '';
    _p2.text = s.period2 != null ? '${s.period2}' : '';
    _p3.text = s.period3 != null ? '${s.period3}' : '';
    _final.text = s.finalMark != null ? '${s.finalMark}' : '';
  }

  void _seedFromDraft(FinalGradeDraft draft) {
    final key = Object.hash(
      draft.saved?.id,
      draft.suggestions.period1,
      draft.suggestions.period2,
      draft.suggestions.period3,
      draft.suggestions.finalMark,
    );
    if (_seededForDraft == key) return;
    _seededForDraft = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (draft.saved != null) {
        final g = draft.saved!;
        _p1.text = g.period1 != null ? '${g.period1}' : '';
        _p2.text = g.period2 != null ? '${g.period2}' : '';
        _p3.text = g.period3 != null ? '${g.period3}' : '';
        _final.text = g.finalMark != null ? '${g.finalMark}' : '';
      } else {
        _applyToControllers(draft.suggestions);
      }
    });
  }

  Future<void> _replaceWithSuggestions() async {
    final draft = await ref.read(finalGradeDraftProvider(_params).future);
    if (!mounted) return;
    setState(() => _applyToControllers(draft.suggestions));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fields filled with averages from grade entries.')),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(finalGradesRepositoryProvider).upsert(
            teacherId: teacher.id,
            studentId: widget.studentId,
            classSubjectId: widget.classSubjectId,
            period1: _parseOptional(_p1.text),
            period2: _parseOptional(_p2.text),
            period3: _parseOptional(_p3.text),
            finalMark: _parseOptional(_final.text),
          );
      ref.invalidate(finalGradeDraftProvider(_params));
      ref.invalidate(finalGradeSavedProvider(_params));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(finalGradeDraftProvider(_params));
    final studentAsync = ref.watch(studentDetailProvider(widget.studentId));

    final title = studentAsync.maybeWhen(
      data: (s) => s != null ? '${s.fullName} — Final' : 'Final grades',
      orElse: () => 'Final grades',
    );

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: widget.classId != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  Text(
                    'Period averages & year final',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.88),
                        ),
                  ),
                ],
              )
            : Text(title),
      ),
      body: draftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
          ),
        ),
        data: (draft) {
          _seedFromDraft(draft);
          final hasSaved = draft.saved != null;
          final hint = hasSaved
              ? 'Values last saved to the database. Use the button below to refill '
                  'from current grade entries if you want fresh suggestions.'
              : 'Each period field is suggested as the average of all individual grades '
                  'in that same period (period 1, 2, or 3). The final is suggested from '
                  'those period averages. Edit anything before saving — nothing is stored until you tap Save.';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _replaceWithSuggestions,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Fill from grade averages'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Period averages',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _p1,
                    label: 'Period 1 (average of grades with period 1)',
                    keyboardType: TextInputType.number,
                    validator: (v) => _optionalInt(v, 'Period 1'),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _p2,
                    label: 'Period 2 (average of grades with period 2)',
                    keyboardType: TextInputType.number,
                    validator: (v) => _optionalInt(v, 'Period 2'),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _p3,
                    label: 'Period 3 (average of grades with period 3)',
                    keyboardType: TextInputType.number,
                    validator: (v) => _optionalInt(v, 'Period 3'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Year final',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _final,
                    label: 'Final (suggested: average of period values above)',
                    keyboardType: TextInputType.number,
                    validator: (v) => _optionalInt(v, 'Final'),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Save to database',
                    onPressed: _save,
                    isLoading: _saving,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
