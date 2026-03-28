import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_draft.dart';
import 'package:teacher_vault/features/final_grades/domain/final_grade_suggestions.dart';
import 'package:teacher_vault/features/final_grades/presentation/providers/final_grades_providers.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class FinalGradeFormScreen extends ConsumerStatefulWidget {
  const FinalGradeFormScreen({
    required this.studentId,
    required this.classSubjectId,
    super.key,
    this.classId,
  });

  final String studentId;
  final String classSubjectId;
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
      const SnackBar(
        content: Text('Fields filled with averages from grade entries.'),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(finalGradesRepositoryProvider)
          .upsert(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(finalGradeDraftProvider(_params));
    final studentAsync = ref.watch(studentDetailProvider(widget.studentId));

    final studentName = studentAsync.maybeWhen(
      data: (s) => s?.fullName,
      orElse: () => null,
    );
    final title = studentName != null
        ? 'Final Grades for $studentName'
        : 'Final Grades';
    const subtitle =
        'Review period averages individually and override final mark.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    TVSecondaryButton(
                      label: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TVCard(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(height: 48),
                          draftAsync.when(
                            loading: () => const Center(
                              child: TVProgressIndicator(),
                            ),
                            error: (e, _) => Center(
                              child: Text(
                                postgrestErrorMessage(e),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                            data: (draft) {
                              _seedFromDraft(draft);
                              final hasSaved = draft.saved != null;

                              return Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              hasSaved
                                                  ? 'Values last saved to database. Refresh below to overwrite these with fresh suggestions.'
                                                  : 'Each period field is auto-calculated as the average of individual grades in that period. You can edit them now.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    TVSecondaryButton(
                                      label: 'Compute Fresh Suggestions',
                                      icon: Icons.calculate_outlined,
                                      onPressed: _replaceWithSuggestions,
                                    ),
                                    const SizedBox(height: 48),
                                    Text(
                                      'Period Averages',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TVTextField(
                                            controller: _p1,
                                            label: 'Period 1',
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                _optionalInt(v, 'P1'),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TVTextField(
                                            controller: _p2,
                                            label: 'Period 2',
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                _optionalInt(v, 'P2'),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TVTextField(
                                            controller: _p3,
                                            label: 'Period 3',
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                _optionalInt(v, 'P3'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 40),
                                    Text(
                                      'Subject Final',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    TVTextField(
                                      controller: _final,
                                      label: 'Final Mark (Average of above)',
                                      keyboardType: TextInputType.number,
                                      validator: (v) =>
                                          _optionalInt(v, 'Final'),
                                    ),
                                    const SizedBox(height: 48),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TVSecondaryButton(
                                          label: 'Cancel',
                                          onPressed: () => context.pop(),
                                        ),
                                        const SizedBox(width: 16),
                                        TVPrimaryButton(
                                          label: 'Save Final Grades',
                                          icon: Icons.check,
                                          isLoading: _saving,
                                          onPressed: _saving ? null : _save,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
