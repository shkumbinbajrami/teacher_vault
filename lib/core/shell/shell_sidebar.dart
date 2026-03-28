import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';

class ShellSidebar extends StatelessWidget {
  const ShellSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(right: BorderSide(color: AppTheme.outlineColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'TeacherVault',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  label: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                  route: AppRoutes.home,
                  currentLocation: location,
                ),
                const SizedBox(height: 8),
                _NavItem(
                  label: 'Classes',
                  icon: Icons.meeting_room_rounded,
                  route: AppRoutes.classes,
                  currentLocation: location,
                ),
                const SizedBox(height: 8),
                _NavItem(
                  label: 'Students',
                  icon: Icons.school_rounded,
                  route: AppRoutes.students,
                  currentLocation: location,
                ),
                const SizedBox(height: 8),
                _NavItem(
                  label: 'Subjects',
                  icon: Icons.menu_book_rounded,
                  route: AppRoutes.subjects,
                  currentLocation: location,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _NavItem(
              label: 'Profile',
              icon: Icons.person_rounded,
              route: AppRoutes.profile,
              currentLocation: location,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.currentLocation,
  });

  final String label;
  final IconData icon;
  final String route;
  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final isActive =
        currentLocation == route ||
        (route != AppRoutes.home && currentLocation.startsWith(route));

    return InkWell(
      onTap: () {
        if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
          Scaffold.of(context).closeDrawer();
        }
        context.go(route);
      },
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
