import 'package:flutter/material.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';
import 'package:teacher_vault/core/widgets/tv_button.dart';

class TVPageHeader extends StatelessWidget {
  const TVPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionIcon,
  });

  final String title;
  final String? subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final IconData? primaryActionIcon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (primaryActionLabel != null && onPrimaryAction != null) ...[
            const SizedBox(width: 16),
            TVPrimaryButton(
              label: primaryActionLabel!,
              icon: primaryActionIcon ?? Icons.add_rounded,
              onPressed: onPrimaryAction,
            ),
          ],
        ],
      ),
    );
  }
}
