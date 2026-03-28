import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/features/classes/domain/school_class.dart';
import 'package:teacher_vault/features/classes/presentation/providers/classes_providers.dart';
import 'package:teacher_vault/features/students/domain/student.dart';
import 'package:teacher_vault/features/students/presentation/providers/students_providers.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  const StudentsListScreen({super.key});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _filterClassId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Student> _applySearch(List<Student> students) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students.where((s) {
      if (s.fullName.toLowerCase().contains(q)) return true;
      final e = s.email?.toLowerCase() ?? '';
      return e.contains(q);
    }).toList();
  }

  Future<void> _onRefresh() async {
    final existing = ref.read(studentsListProvider).valueOrNull ?? [];
    for (final s in existing) {
      ref.invalidate(studentClassesProvider(s.id));
    }
    ref.invalidate(studentsListProvider);
    await ref.read(studentsListProvider.future);
    final classId = _filterClassId;
    if (classId != null) {
      ref.invalidate(classEnrolledStudentsProvider(classId));
      await ref.read(classEnrolledStudentsProvider(classId).future);
    }
  }

  Widget _buildListFromStudents({
    required BuildContext context,
    required List<Student> students,
    required bool hadSourceStudents,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filtered = _applySearch(students);

    if (!hadSourceStudents) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    color: scheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _filterClassId == null
                      ? 'No students yet'
                      : 'No students in this class',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _filterClassId == null
                      ? 'Add students, then enroll them in classes from each class page.'
                      : 'Enroll students from the class page, or pick another class.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        children: [
          Center(
            child: Text(
              'No students match your search.',
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = filtered[index];
        return _StudentCard(
          student: s,
          onTap: () => context.push(AppRoutes.studentDetailPath(s.id)),
        );
      },
    );
  }

  Widget _buildStudentListBody(BuildContext context) {
    if (_filterClassId == null) {
      return ref.watch(studentsListProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      postgrestErrorMessage(e),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(studentsListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (students) => RefreshIndicator(
              onRefresh: _onRefresh,
              child: _buildListFromStudents(
                context: context,
                students: students,
                hadSourceStudents: students.isNotEmpty,
              ),
            ),
          );
    }

    final classId = _filterClassId!;
    return ref.watch(classEnrolledStudentsProvider(classId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    postgrestErrorMessage(e),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(
                      classEnrolledStudentsProvider(classId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (students) => RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildListFromStudents(
              context: context,
              students: students,
              hadSourceStudents: students.isNotEmpty,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesListProvider);

    return Scaffold(
      appBar: TeacherVaultAppBar(
        title: const Text('Students'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudentsFilterBar(
            searchController: _searchController,
            onSearchChanged: () => setState(() {}),
            filterClassId: _filterClassId,
            onClassChanged: (id) => setState(() => _filterClassId = id),
            classesAsync: classesAsync,
          ),
          Expanded(child: _buildStudentListBody(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.studentsNew),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add student'),
      ),
    );
  }
}

class _StudentsFilterBar extends StatelessWidget {
  const _StudentsFilterBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filterClassId,
    required this.onClassChanged,
    required this.classesAsync,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final String? filterClassId;
  final ValueChanged<String?> onClassChanged;
  final AsyncValue<List<SchoolClass>> classesAsync;

  static InputBorder _fieldBorder(ColorScheme scheme) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const rowHeight = 44.0;
    const filterWidth = 160.0;
    const searchMaxWidth = 200.0;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: searchMaxWidth),
                  child: SizedBox(
                    height: rowHeight,
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => onSearchChanged(),
                      textInputAction: TextInputAction.search,
                      style: textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Name or email',
                        hintStyle: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          maxHeight: rowHeight,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged();
                                },
                              )
                            : null,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        border: _fieldBorder(scheme),
                        enabledBorder: _fieldBorder(scheme),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                          borderSide:
                              BorderSide(color: scheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Filters:',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: filterWidth,
                      height: rowHeight,
                      child: classesAsync.when(
                        loading: () => Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        error: (_, __) => Tooltip(
                          message: 'Could not load classes for filter.',
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: scheme.error,
                            size: 22,
                          ),
                        ),
                        data: (classes) {
                          return DropdownButtonFormField<String?>(
                            value: filterClassId,
                            isExpanded: true,
                            isDense: true,
                            style: textTheme.bodyMedium,
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Class',
                              isDense: true,
                              filled: false,
                              contentPadding:
                                  const EdgeInsetsDirectional.only(
                                start: 12,
                                end: 8,
                                top: 10,
                                bottom: 10,
                              ),
                              border: _fieldBorder(scheme),
                              enabledBorder: _fieldBorder(scheme),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius,
                                ),
                                borderSide: BorderSide(
                                  color: scheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All classes'),
                              ),
                              ...classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: onClassChanged,
                            selectedItemBuilder: (context) {
                              return [
                                Align(
                                  alignment:
                                      AlignmentDirectional.centerStart,
                                  child: Text(
                                    'All classes',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...classes.map(
                                  (c) => Align(
                                    alignment:
                                        AlignmentDirectional.centerStart,
                                    child: Text(
                                      c.name,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ];
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({
    required this.student,
    required this.onTap,
  });

  final Student student;
  final VoidCallback onTap;

  static const double _avatarSize = 40;

  static String _classesLine(AsyncValue<List<SchoolClass>> async) {
    return async.when(
      data: (classes) {
        if (classes.isEmpty) return 'Not enrolled in a class';
        if (classes.length == 1) return classes.first.name;
        final names = classes.map((c) => c.name).take(2).join(', ');
        if (classes.length == 2) return names;
        return '$names +${classes.length - 2} more';
      },
      loading: () => 'Loading classes…',
      error: (_, __) => 'Could not load classes',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = student;
    final initial =
        s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?';

    final classesAsync = ref.watch(studentClassesProvider(s.id));

    Widget avatar;
    final url = s.avatarUrl;
    if (url != null && url.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Image.network(
          url,
          width: _avatarSize,
          height: _avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderAvatar(
            scheme: scheme,
            textTheme: textTheme,
            initial: initial,
          ),
        ),
      );
    } else {
      avatar = _placeholderAvatar(
        scheme: scheme,
        textTheme: textTheme,
        initial: initial,
      );
    }

    final email = s.email?.trim();
    final emailDisplay =
        email != null && email.isNotEmpty ? email : '—';

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                flex: 28,
                child: Text(
                  s.fullName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 32,
                child: Text(
                  emailDisplay,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 26,
                child: Row(
                  children: [
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _classesLine(classesAsync),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _placeholderAvatar({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required String initial,
  }) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: textTheme.titleSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
