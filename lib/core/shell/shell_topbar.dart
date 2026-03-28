import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/features/auth/presentation/providers/auth_repository_provider.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/providers/teacher_profile_providers.dart';

class ShellTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const ShellTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(currentTeacherProvider);
    final client = ref.watch(supabaseProvider);
    final email = client.auth.currentUser?.email ?? '';

    final teacher = teacherAsync.maybeWhen(data: (t) => t, orElse: () => null);
    final avatarUrl = teacher?.avatarUrl?.trim();

    final nameForInitial = teacherAsync.maybeWhen(
      data: (t) {
        final n = t?.fullName?.trim();
        if (n != null && n.isNotEmpty) return n;
        final at = email.indexOf('@');
        if (at > 0) return email.substring(0, at);
        return 'T';
      },
      orElse: () => 'T',
    );

    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.outlineColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Basic breadcrumbs/title placeholder
          const Spacer(),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            tooltip: 'Sign out',
            icon: const Icon(
              Icons.logout_rounded,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => context.push(AppRoutes.profile),
            borderRadius: BorderRadius.circular(20),
            child: _ProfileAvatar(
              url: avatarUrl,
              initial: nameForInitial.isNotEmpty
                  ? nameForInitial[0].toUpperCase()
                  : '?',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.url, required this.initial});
  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url!));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      foregroundColor: AppTheme.primaryColor,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
