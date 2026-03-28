import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class ClassFormScreen extends ConsumerStatefulWidget {
  const ClassFormScreen({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends ConsumerState<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _schoolYear = TextEditingController();
  final _description = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _seededForClassId;

  bool get _isEdit => widget.classId != null;

  @override
  void dispose() {
    _name.dispose();
    _schoolYear.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(SchoolClass schoolClass) {
    if (_seededForClassId == schoolClass.id) return;
    _seededForClassId = schoolClass.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text = schoolClass.name;
      _schoolYear.text = schoolClass.schoolYear;
      _description.text = schoolClass.description ?? '';
      _isActive = schoolClass.isActive;
      setState(() {});
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final teacher = await ref.read(currentTeacherProvider.future);
    if (teacher == null) return;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref
            .read(classesRepositoryProvider)
            .update(
              teacherId: teacher.id,
              classId: widget.classId!,
              name: _name.text,
              schoolYear: _schoolYear.text,
              description: _description.text,
              isActive: _isActive,
            );
        ref.invalidate(classDetailProvider(widget.classId!));
      } else {
        await ref
            .read(classesRepositoryProvider)
            .create(
              teacherId: teacher.id,
              name: _name.text,
              schoolYear: _schoolYear.text,
              description: _description.text,
              isActive: _isActive,
            );
      }
      ref.invalidate(classesListProvider);
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
    final title = _isEdit ? 'Edit Class' : 'Create Class';
    final subtitle = _isEdit
        ? 'Update details for this class.'
        : 'Add a new class to your workspace.';

    Widget body;
    if (_isEdit) {
      final detailAsync = ref.watch(classDetailProvider(widget.classId!));
      body = detailAsync.when(
        loading: () => const TVProgressIndicator(),
        error: (e, _) => Center(
          child: Text(
            postgrestErrorMessage(e),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (c) {
          if (c == null) return const Center(child: Text('Class not found.'));
          _seed(c);
          return _formContent();
        },
      );
    } else {
      body = _formContent();
    }

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
                          body,
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

  Widget _formContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TVTextField(
            controller: _name,
            label: 'Class Name',
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          TVTextField(
            controller: _schoolYear,
            label: 'School Year',
            textInputAction: TextInputAction.next,
            hintText: 'e.g. 2025–2026',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          TVTextField(
            controller: _description,
            label: 'Description (Optional)',
            maxLines: 4,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.outlineColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Status',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Inactive classes are hidden by default.',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TVSecondaryButton(
                label: 'Cancel',
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 16),
              TVPrimaryButton(
                label: _isEdit ? 'Save Changes' : 'Create Class',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
