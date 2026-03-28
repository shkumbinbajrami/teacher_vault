import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/utils/postgrest_error_message.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';
import 'package:teacher_vault/core/widgets/tv_card.dart';
import 'package:teacher_vault/core/widgets/tv_skeleton.dart';
import 'package:teacher_vault/core/widgets/tv_text_field.dart';
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
      await ref
          .read(teacherRepositoryProvider)
          .updateAvatarUrl(teacherId: teacherId, avatarUrl: null);
      ref.invalidate(currentTeacherProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
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
        const SnackBar(
          content: Text('Could not read the image. Try another file.'),
        ),
      );
      return;
    }

    var ext = (picked.extension ?? '').trim().toLowerCase();
    if (ext.isEmpty && picked.name.contains('.')) {
      ext = picked.name.split('.').last.toLowerCase();
    }
    if (ext.isEmpty) {
      ext = 'jpg';
    }

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
        await ref
            .read(teacherRepositoryProvider)
            .updateAvatarUrl(teacherId: teacherId, avatarUrl: url);
        ref.invalidate(currentTeacherProvider);
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e))));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo saved.')));
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message.isNotEmpty ? e.message : 'Upload failed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save(String teacherId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(profileUpdateControllerProvider.notifier)
        .submit(
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

    ref.listen(profileUpdateControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev?.isLoading == true) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Profile updated')));
          }
        },
        error: (e, _) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(postgrestErrorMessage(e)))),
      );
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: teacherAsync.when(
          loading: () => const TVProgressIndicator(),
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
                  onPressed: () => ref.invalidate(currentTeacherProvider),
                ),
              ],
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
                  final wide = constraints.maxWidth >= 960;
                  final pad = const EdgeInsets.fromLTRB(32, 24, 32, 64);

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

                  return SingleChildScrollView(
                    padding: pad,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHeroCard(teacher: teacher),
                        const SizedBox(height: 24),
                        summaryAsync.when(
                          loading: () => const TVProgressIndicator(),
                          error: (e, _) => TVCard(
                            child: Text(
                              'Could not load workspace stats: ${postgrestErrorMessage(e)}',
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                          data: (s) => _WorkspaceStatsBlock(summary: s),
                        ),
                        const SizedBox(height: 24),
                        if (!wide) ...[
                          edit,
                          const SizedBox(height: 24),
                          account,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: edit),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: account),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.teacher});
  final Teacher teacher;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = teacher.fullName?.trim().isNotEmpty == true
        ? teacher.fullName!.trim()
        : 'Teacher';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget avatar;
    final url = teacher.avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(url, width: 96, height: 96, fit: BoxFit.cover),
      );
    } else {
      avatar = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return TVCard(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  name,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (teacher.email != null &&
                    teacher.email!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          teacher.email!.trim(),
                          style: textTheme.titleMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (teacher.bio != null && teacher.bio!.trim().isNotEmpty)
                  Text(
                    teacher.bio!.trim(),
                    style: textTheme.bodyLarge?.copyWith(height: 1.5),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStatsBlock extends StatelessWidget {
  const _WorkspaceStatsBlock({required this.summary});
  final TeacherWorkspaceSummary summary;

  @override
  Widget build(BuildContext context) {
    return TVCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Workspace',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '${summary.classCount}',
                  label: 'Classes',
                  icon: Icons.meeting_room_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MiniStat(
                  value: '${summary.studentCount}',
                  label: 'Students',
                  icon: Icons.groups_outlined,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MiniStat(
                  value: '${summary.subjectCount}',
                  label: 'Subjects',
                  icon: Icons.menu_book_outlined,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MiniStat(
                  value: '${summary.classSubjectAssignmentCount}',
                  label: 'Links',
                  icon: Icons.link_rounded,
                  color: AppTheme.outlineColor,
                ),
              ),
            ],
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
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
    final textTheme = Theme.of(context).textTheme;

    return TVCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Analytics',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          if (user != null) ...[
            _ReadonlyField(label: 'Signed in as', value: user!.email ?? '—'),
            const SizedBox(height: 16),
            _ReadonlyField(
              label: 'Last sign-in',
              value: formatAuthInstant(user!.lastSignInAt),
            ),
            const SizedBox(height: 16),
            _ReadonlyField(
              label: 'Account created',
              value: formatAuthInstant(user!.createdAt),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.outlineColor),
            const SizedBox(height: 24),
            _IdRow(label: 'Auth User ID', value: user!.id),
            const SizedBox(height: 16),
          ],
          _IdRow(label: 'Teacher Record ID', value: teacher.id),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _IdRow extends StatelessWidget {
  const _IdRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border.all(color: AppTheme.outlineColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$label copied')));
                },
                child: const Icon(
                  Icons.copy_outlined,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final textTheme = Theme.of(context).textTheme;
    final busy = saving || uploadingAvatar;

    return TVCard(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Profile',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.outlineColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListenableBuilder(
                listenable: avatarUrl,
                builder: (context, _) {
                  final hasPhoto = avatarUrl.text.trim().isNotEmpty;
                  return Row(
                    children: [
                      if (hasPhoto)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            avatarUrl.text.trim(),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            border: Border.all(color: AppTheme.outlineColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      const SizedBox(width: 20),
                      if (uploadingAvatar)
                        const TVProgressIndicator()
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TVSecondaryButton(
                                label: 'Upload Photo',
                                icon: Icons.upload_rounded,
                                onPressed: busy ? null : onPickAvatar,
                              ),
                              const SizedBox(height: 8),
                              if (hasPhoto)
                                InkWell(
                                  onTap: busy ? null : onClearAvatar,
                                  child: Text(
                                    'Remove photo',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            TVTextField(
              controller: fullName,
              label: 'Full Name',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TVTextField(
              controller: email,
              label: 'Email (Optional)',
              keyboardType: TextInputType.emailAddress,
              validator: optionalEmailError,
            ),
            const SizedBox(height: 16),
            TVTextField(controller: bio, label: 'Bio', maxLines: 4),
            const SizedBox(height: 32),
            TVPrimaryButton(
              label: 'Save Changes',
              icon: Icons.check_circle_outline,
              isLoading: saving,
              onPressed: busy ? null : onSave,
            ),
          ],
        ),
      ),
    );
  }
}
