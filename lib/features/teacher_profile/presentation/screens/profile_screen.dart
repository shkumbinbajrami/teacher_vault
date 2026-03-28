import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/teacher_vault_app_bar.dart';
import 'package:teacher_vault/core/widgets/app_button.dart';
import 'package:teacher_vault/core/widgets/app_text_field.dart';
import 'package:teacher_vault/features/teacher_profile/data/teacher_avatar_storage.dart';
import 'package:teacher_vault/features/teacher_profile/domain/teacher.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_workspace_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _avatarUrl = TextEditingController();
  final _bio = TextEditingController();
  String? _seededForTeacherId;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _avatarUrl.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _seedFieldsIfNeeded({
    required String teacherId,
    String? fullName,
    String? email,
    String? avatarUrl,
    String? bio,
  }) {
    if (_seededForTeacherId != teacherId) {
      _seededForTeacherId = teacherId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fullName.text = fullName ?? '';
        _email.text = email ?? '';
        _avatarUrl.text = avatarUrl ?? '';
        _bio.text = bio ?? '';
      });
      return;
    }
    // Same teacher (e.g. after refresh / invalidate): keep avatar URL aligned with DB.
    final server = avatarUrl ?? '';
    if (_avatarUrl.text.trim() == server.trim()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_avatarUrl.text.trim() != server.trim()) {
        _avatarUrl.text = server;
      }
    });
  }

  Future<void> _clearAvatarAndPersist(String teacherId) async {
    _avatarUrl.clear();
    setState(() {});
    try {
      await ref.read(teacherRepositoryProvider).updateAvatarUrl(
            teacherId: teacherId,
            avatarUrl: null,
          );
      ref.invalidate(currentTeacherProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(postgrestErrorMessage(e))),
      );
    }
  }

  String? _optionalEmailError(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  static String _imageContentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickAndUploadAvatar(String teacherId) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message?.isNotEmpty == true
                ? e.message!
                : 'Could not open the file picker (${e.code}).',
          ),
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file picker: $e')),
      );
      return;
    }

    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        picked.path != null &&
        picked.path!.isNotEmpty) {
      try {
        bytes = await File(picked.path!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the image. Try another file.')),
      );
      return;
    }

    var ext = (picked.extension ?? '').trim().toLowerCase();
    if (ext.isEmpty && picked.name.contains('.')) {
      ext = picked.name.split('.').last.toLowerCase();
    }
    if (ext.isEmpty) ext = 'jpg';

    setState(() => _uploadingAvatar = true);
    try {
      final client = ref.read(supabaseProvider);
      final storage = TeacherAvatarStorage(client);
      final url = await storage.uploadTeacherAvatar(
        teacherId: teacherId,
        bytes: bytes,
        contentType: _imageContentTypeForExtension(ext),
        extension: ext,
      );
      if (!mounted) return;
      _avatarUrl.text = url;
      try {
        await ref.read(teacherRepositoryProvider).updateAvatarUrl(
              teacherId: teacherId,
              avatarUrl: url,
            );
        ref.invalidate(currentTeacherProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(postgrestErrorMessage(e))),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo saved.')),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.isNotEmpty ? e.message : 'Upload failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save(String teacherId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(profileUpdateControllerProvider.notifier).submit(
          teacherId: teacherId,
          fullName: _fullName.text,
          email: _email.text,
          avatarUrl: _avatarUrl.text,
          bio: _bio.text,
        );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(currentTeacherProvider);
    ref.invalidate(teacherWorkspaceSummaryProvider);
    await Future.wait([
      ref.read(currentTeacherProvider.future),
      ref.read(teacherWorkspaceSummaryProvider.future),
    ]);
  }

  static String _formatDate(DateTime? t) {
    if (t == null) return '—';
    final l = t.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  /// Supabase [User] timestamps may be [DateTime] or ISO [String].
  static String _formatAuthInstant(dynamic t) {
    if (t == null) return '—';
    if (t is DateTime) return _formatDate(t);
    if (t is String) {
      final parsed = DateTime.tryParse(t);
      return parsed != null ? _formatDate(parsed) : t;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(currentTeacherProvider);
    final summaryAsync = ref.watch(teacherWorkspaceSummaryProvider);
    final update = ref.watch(profileUpdateControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(profileUpdateControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev?.isLoading == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated')),
            );
          }
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(postgrestErrorMessage(e))),
          );
        },
      );
    });

    return Scaffold(
      appBar: teacherAsync.maybeWhen(
        data: (t) {
          if (t == null) {
            return const TeacherVaultAppBar(title: Text('Your profile'));
          }
          return TeacherVaultAppBar(
            title: const Text('Your profile'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _TeacherBarAvatar(teacher: t),
              ),
            ],
          );
        },
        orElse: () => const TeacherVaultAppBar(title: Text('Your profile')),
      ),
      body: teacherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(postgrestErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(currentTeacherProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (teacher) {
          if (teacher == null) {
            return const Center(child: Text('Sign in to view your profile.'));
          }

          _seedFieldsIfNeeded(
            teacherId: teacher.id,
            fullName: teacher.fullName,
            email: teacher.email,
            avatarUrl: teacher.avatarUrl,
            bio: teacher.bio,
          );

          final saving = update.isLoading;
          final user = ref.watch(supabaseProvider).auth.currentUser;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPad = 20.0;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    12,
                    horizontalPad,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeroCard(teacher: teacher),
                      const SizedBox(height: 14),
                      summaryAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        error: (e, _) => _InfoNoticeCard(
                          scheme: scheme,
                          message:
                              'Could not load workspace stats: ${postgrestErrorMessage(e)}',
                          isError: true,
                        ),
                        data: (s) => _WorkspaceStatsBlock(
                          summary: s,
                          bodyWidth: constraints.maxWidth - horizontalPad * 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _QuickLinksRow(),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, inner) {
                          final w = inner.maxWidth;
                          final wide = w >= 960;
                          final account = _AccountDetailsCard(
                            teacher: teacher,
                            user: user,
                            formatAuthInstant: _formatAuthInstant,
                          );
                          final edit = _EditProfileCard(
                            formKey: _formKey,
                            fullName: _fullName,
                            email: _email,
                            avatarUrl: _avatarUrl,
                            bio: _bio,
                            optionalEmailError: _optionalEmailError,
                            saving: saving,
                            uploadingAvatar: _uploadingAvatar,
                            onPickAvatar: () => _pickAndUploadAvatar(teacher.id),
                            onClearAvatar: () => _clearAvatarAndPersist(teacher.id),
                            onSave: () => _save(teacher.id),
                          );
                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                account,
                                const SizedBox(height: 14),
                                edit,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: account),
                              const SizedBox(width: 20),
                              Expanded(flex: 5, child: edit),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Small avatar shown in the profile screen app bar actions.
class _TeacherBarAvatar extends StatelessWidget {
  const _TeacherBarAvatar({required this.teacher});

  final Teacher teacher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
    final name = teacher.fullName?.trim().isNotEmpty == true
        ? teacher.fullName!.trim()
        : 'Teacher';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = teacher.avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: onPrimary.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: onPrimary.withValues(alpha: 0.2),
      foregroundColor: onPrimary,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.teacher});

  final Teacher teacher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = teacher;
    final name = t.fullName?.trim().isNotEmpty == true
        ? t.fullName!.trim()
        : 'Teacher';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget avatar;
    const r = 36.0;
    final url = t.avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(
        radius: r,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: r,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.primary,
        child: Text(
          initial,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(t.isActive ? 'Active' : 'Inactive'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                        ),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                    ],
                  ),
                  if (t.email != null && t.email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.email!.trim(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (t.bio != null && t.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      t.bio!.trim(),
                      style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceStatsBlock extends StatelessWidget {
  const _WorkspaceStatsBlock({
    required this.summary,
    required this.bodyWidth,
  });

  final TeacherWorkspaceSummary summary;
  final double bodyWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = summary;
    final oneRow = bodyWidth >= 800;

    Widget statGrid() {
      final tiles = [
        _MiniStat(
          value: '${s.classCount}',
          label: s.classCount == 1 ? 'Class' : 'Classes',
          icon: Icons.meeting_room_outlined,
          color: scheme.primary,
        ),
        _MiniStat(
          value: '${s.studentCount}',
          label: s.studentCount == 1 ? 'Student' : 'Students',
          icon: Icons.groups_outlined,
          color: scheme.tertiary,
        ),
        _MiniStat(
          value: '${s.subjectCount}',
          label: s.subjectCount == 1 ? 'Subject' : 'Subjects',
          icon: Icons.menu_book_outlined,
          color: scheme.primary,
        ),
        _MiniStat(
          value: '${s.classSubjectAssignmentCount}',
          label: 'Class–subject links',
          icon: Icons.link_rounded,
          color: scheme.secondary,
        ),
      ];
      if (oneRow) {
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      }
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 8),
              Expanded(child: tiles[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 8),
              Expanded(child: tiles[3]),
            ],
          ),
        ],
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your workspace',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Totals from your Teacher Vault data (this session).',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            statGrid(),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickLinksRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.classes),
          icon: const Icon(Icons.meeting_room_outlined, size: 18),
          label: const Text('Classes'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.students),
          icon: const Icon(Icons.groups_outlined, size: 18),
          label: const Text('Students'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.subjects),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('Subjects'),
        ),
      ],
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard({
    required this.teacher,
    required this.user,
    required this.formatAuthInstant,
  });

  final Teacher teacher;
  final User? user;
  final String Function(dynamic t) formatAuthInstant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account & record IDs',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Useful for support. Sign-in data comes from Supabase Auth; teaching data from your `teachers` row.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (user != null) ...[
              _IdRow(
                label: 'Auth user ID',
                value: user!.id,
                scheme: scheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 10),
              _ReadonlyField(
                label: 'Signed in as',
                value: user!.email ?? '—',
              ),
              const SizedBox(height: 6),
              _ReadonlyField(
                label: 'Last sign-in',
                value: formatAuthInstant(user!.lastSignInAt),
              ),
              const SizedBox(height: 6),
              _ReadonlyField(
                label: 'Account created',
                value: formatAuthInstant(user!.createdAt),
              ),
              const SizedBox(height: 12),
            ],
            _IdRow(
              label: 'Teacher record ID',
              value: teacher.id,
              scheme: scheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _IdRow extends StatelessWidget {
  const _IdRow({
    required this.label,
    required this.value,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_outlined, size: 18, color: scheme.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoNoticeCard extends StatelessWidget {
  const _InfoNoticeCard({
    required this.scheme,
    required this.message,
    this.isError = false,
  });

  final ColorScheme scheme;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isError ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? scheme.onErrorContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EditProfileCard extends StatelessWidget {
  const _EditProfileCard({
    required this.formKey,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    required this.optionalEmailError,
    required this.saving,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullName;
  final TextEditingController email;
  final TextEditingController avatarUrl;
  final TextEditingController bio;
  final String? Function(String?) optionalEmailError;
  final bool saving;
  final bool uploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onClearAvatar;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = saving || uploadingAvatar;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person_outline_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit profile',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Photo is stored in Supabase Storage; name and bio save to your teachers row.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListenableBuilder(
                    listenable: avatarUrl,
                    builder: (context, _) {
                      final hasPhoto = avatarUrl.text.trim().isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile photo',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Builder(
                                builder: (context) {
                                  final url = avatarUrl.text.trim();
                                  const size = 88.0;
                                  if (url.isEmpty) {
                                    return CircleAvatar(
                                      radius: size / 2,
                                      backgroundColor: scheme.primaryContainer,
                                      foregroundColor: scheme.primary,
                                      child: Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 32,
                                        color: scheme.primary,
                                      ),
                                    );
                                  }
                                  return CircleAvatar(
                                    radius: size / 2,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                    backgroundImage: NetworkImage(url),
                                    onBackgroundImageError: (_, __) {},
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: busy ? null : onPickAvatar,
                                      icon: uploadingAvatar
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: scheme.primary,
                                              ),
                                            )
                                          : const Icon(Icons.upload_rounded, size: 20),
                                      label: Text(uploadingAvatar ? 'Uploading…' : 'Choose photo'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: busy || !hasPhoto ? null : onClearAvatar,
                                      child: const Text('Remove photo'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'JPG, PNG, or WebP · up to ${TeacherAvatarStorage.maxBytes ~/ (1024 * 1024)} MB · '
                            'bucket “${TeacherAvatarStorage.bucketName}” must exist in Supabase.',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Advanced: paste image URL',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Skip upload and point to any public image URL.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    AppTextField(
                      controller: avatarUrl,
                      label: 'Image URL',
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AppTextField(
                controller: fullName,
                label: 'Full name',
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: email,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: optionalEmailError,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: bio,
                label: 'Bio (optional)',
                textInputAction: TextInputAction.newline,
                maxLines: 4,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Save changes',
                isLoading: saving,
                onPressed: busy ? null : onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
