import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';

/// Top navigation: full-width primary strip so it reads as chrome, not as a content card.
class TeacherVaultAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TeacherVaultAppBar.dashboard({
    super.key,
    required this.onProfile,
    required this.onSignOut,
    this.profileAvatarUrl,
    this.profileNameForInitial,
  }) : title = null,
       actions = null,
       leading = null,
       automaticallyImplyLeading = true,
       _isDashboard = true;

  const TeacherVaultAppBar({
    super.key,
    required Widget this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  }) : onProfile = null,
       onSignOut = null,
       profileAvatarUrl = null,
       profileNameForInitial = null,
       _isDashboard = false;

  final bool _isDashboard;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final VoidCallback? onProfile;
  final VoidCallback? onSignOut;

  /// Public image URL for the signed-in teacher (dashboard profile control).
  final String? profileAvatarUrl;

  /// Display name used for the initial letter when [profileAvatarUrl] is null.
  final String? profileNameForInitial;

  static const double _verticalPad = 10;
  static const double _innerHeight = 56;

  @override
  Size get preferredSize =>
      const Size.fromHeight(_innerHeight + _verticalPad * 2);

  @override
  Widget build(BuildContext context) {
    assert(
      _isDashboard || title != null,
      'TeacherVaultAppBar requires a title',
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final onPrimary = scheme.onPrimary;
    final iconStyle = IconButton.styleFrom(
      foregroundColor: onPrimary,
      backgroundColor: onPrimary.withValues(alpha: 0.14),
    );

    return Material(
      color: scheme.primary,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, _verticalPad, 12, _verticalPad),
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(iconButtonTheme: IconButtonThemeData(style: iconStyle)),
          child: SizedBox(
            height: _innerHeight,
            child: _isDashboard
                ? _DashboardRow(
                    scheme: scheme,
                    textTheme: textTheme,
                    onPrimary: onPrimary,
                    onProfile: onProfile!,
                    onSignOut: onSignOut!,
                    profileAvatarUrl: profileAvatarUrl,
                    profileNameForInitial: profileNameForInitial,
                  )
                : _StandardRow(
                    scheme: scheme,
                    textTheme: textTheme,
                    onPrimary: onPrimary,
                    title: title!,
                    actions: actions,
                    leading: leading,
                    automaticallyImplyLeading: automaticallyImplyLeading,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashboardRow extends StatelessWidget {
  const _DashboardRow({
    required this.scheme,
    required this.textTheme,
    required this.onPrimary,
    required this.onProfile,
    required this.onSignOut,
    this.profileAvatarUrl,
    this.profileNameForInitial,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final Color onPrimary;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;
  final String? profileAvatarUrl;
  final String? profileNameForInitial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: onPrimary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Icon(Icons.auto_stories_rounded, color: onPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teacher Vault',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: onPrimary,
                ),
              ),
              Text(
                'Dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: onPrimary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onProfile,
          tooltip: 'Profile',
          icon: _DashboardProfileAvatar(
            onPrimary: onPrimary,
            url: profileAvatarUrl,
            nameForInitial: profileNameForInitial,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onSignOut,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

/// Sized for [IconButton] — same visual weight as outline person icon (~24px).
class _DashboardProfileAvatar extends StatelessWidget {
  const _DashboardProfileAvatar({
    required this.onPrimary,
    this.url,
    this.nameForInitial,
  });

  final Color onPrimary;
  final String? url;
  final String? nameForInitial;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: onPrimary.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(trimmed),
        onBackgroundImageError: (_, __) {},
      );
    }
    final n = nameForInitial?.trim();
    final initial = (n != null && n.isNotEmpty) ? n[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 14,
      backgroundColor: onPrimary.withValues(alpha: 0.2),
      foregroundColor: onPrimary,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StandardRow extends StatelessWidget {
  const _StandardRow({
    required this.scheme,
    required this.textTheme,
    required this.onPrimary,
    required this.title,
    required this.actions,
    required this.leading,
    required this.automaticallyImplyLeading,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final Color onPrimary;
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    final Widget leadingSlot =
        leading ??
        (automaticallyImplyLeading && canPop
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : const SizedBox(width: 4));

    return Row(
      children: [
        leadingSlot,
        const SizedBox(width: 4),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle(
              style: (textTheme.titleMedium ?? const TextStyle(fontSize: 18))
                  .copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                    color: onPrimary,
                  ),
              child: title,
            ),
          ),
        ),
        if (actions != null) ...actions!,
      ],
    );
  }
}
