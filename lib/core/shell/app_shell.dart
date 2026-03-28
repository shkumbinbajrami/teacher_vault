import 'package:flutter/material.dart';
import 'package:teacher_vault/core/shell/shell_sidebar.dart';
import 'package:teacher_vault/core/shell/shell_topbar.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          if (isDesktop) const ShellSidebar(),

          Expanded(
            child: Column(
              children: [
                if (isDesktop)
                  const ShellTopBar()
                else
                  AppBar(
                    title: const Text('TeacherVault'),
                    backgroundColor: AppTheme.surfaceColor,
                    scrolledUnderElevation: 0,
                  ),
                Expanded(child: ClipRect(child: child)),
              ],
            ),
          ),
        ],
      ),
      drawer: isDesktop ? null : const Drawer(child: ShellSidebar()),
    );
  }
}
