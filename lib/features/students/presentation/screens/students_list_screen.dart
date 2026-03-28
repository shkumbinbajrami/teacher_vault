import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_badge.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_empty_state.dart';
import 'package:teacher_vault/core/widgets/tv_page_header.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
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

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TVPageHeader(
                title: 'Students',
                subtitle: 'Manage student profiles and enrollment.',
                primaryActionLabel: 'Add Student',
                onPrimaryAction: () => context.push(AppRoutes.studentsNew),
              ),
              _StudentsFilterBar(
                searchController: _searchController,
                onSearchChanged: () => setState(() {}),
                filterClassId: _filterClassId,
                onClassChanged: (id) => setState(() => _filterClassId = id),
                classesAsync: classesAsync,
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildStudentListBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentListBody(BuildContext context) {
    if (_filterClassId == null) {
      return ref
          .watch(studentsListProvider)
          .when(
            loading: () => const TVSkeletonList(),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    postgrestErrorMessage(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                  const SizedBox(height: 16),
                  TVSecondaryButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(studentsListProvider),
                  ),
                ],
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
    return ref
        .watch(classEnrolledStudentsProvider(classId))
        .when(
          loading: () => const TVSkeletonList(),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  postgrestErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                const SizedBox(height: 16),
                TVSecondaryButton(
                  label: 'Retry',
                  onPressed: () =>
                      ref.invalidate(classEnrolledStudentsProvider(classId)),
                ),
              ],
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

  Widget _buildListFromStudents({
    required BuildContext context,
    required List<Student> students,
    required bool hadSourceStudents,
  }) {
    final filtered = _applySearch(students);

    if (!hadSourceStudents) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TVEmptyState(
            title: _filterClassId == null
                ? 'No students yet'
                : 'No students in this class',
            message: _filterClassId == null
                ? 'Add students, then enroll them in classes.'
                : 'Enroll students from the class page, or pick another class.',
            icon: Icons.groups_outlined,
            actionLabel: _filterClassId == null ? 'Add First Student' : null,
            onAction: _filterClassId == null
                ? () => context.push(AppRoutes.studentsNew)
                : null,
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          TVEmptyState(
            title: 'No matched students',
            message: 'Try adjusting your search filters.',
            icon: Icons.search_off_rounded,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 64),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = filtered[index];
        return _StudentCard(
          student: s,
          onTap: () => context.push(AppRoutes.studentDetailPath(s.id)),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: classesAsync.when(
            loading: () => const TVProgressIndicator(),
            error: (_, __) => const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorColor,
            ),
            data: (classes) {
              return DropdownButtonFormField<String?>(
                value: filterClassId,
                isExpanded: true,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textPrimaryColor,
                ),
                decoration: const InputDecoration(hintText: 'Filter by Class'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  ...classes.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onClassChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  static const double _avatarSize = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final s = student;
    final initial = s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?';

    Widget avatar;
    final url = s.avatarUrl;
    if (url != null && url.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: _avatarSize,
          height: _avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderAvatar(initial),
        ),
      );
    } else {
      avatar = _placeholderAvatar(initial);
    }

    final emailDisplay = (s.email?.trim().isNotEmpty ?? false)
        ? s.email!.trim()
        : 'No email provided';

    return TVCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.fullName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emailDisplay,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _ClassesInfo(studentId: s.id)),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.outlineColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderAvatar(String initial) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ClassesInfo extends ConsumerWidget {
  const _ClassesInfo({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(studentClassesProvider(studentId));
    final textTheme = Theme.of(context).textTheme;

    return classesAsync.when(
      data: (classes) {
        if (classes.isEmpty) {
          return const TVBadge(label: 'Unenrolled', type: TVBadgeType.warning);
        }
        if (classes.length == 1) {
          return TVBadge(
            label: classes.first.name,
            type: TVBadgeType.neutral,
            icon: Icons.meeting_room_outlined,
          );
        }
        final names = classes.map((c) => c.name).take(2).join(', ');
        final label = classes.length == 2
            ? names
            : '$names +${classes.length - 2}';
        return TVBadge(
          label: label,
          type: TVBadgeType.neutral,
          icon: Icons.meeting_room_outlined,
        );
      },
      loading: () => Text(
        'Loading...',
        style: textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondaryColor,
        ),
      ),
      error: (_, __) => Text(
        'Error',
        style: textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
      ),
    );
  }
}
