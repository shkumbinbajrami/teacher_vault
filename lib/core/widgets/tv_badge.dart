import 'package:flutter/material.dart';
import 'package:teacher_vault/core/theme/app_theme.dart';

enum TVBadgeType { neutral, success, warning, error }

class TVBadge extends StatelessWidget {
  const TVBadge({
    super.key,
    required this.label,
    this.type = TVBadgeType.neutral,
    this.icon,
  });

  final String label;
  final TVBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color getBackgroundColor() {
      switch (type) {
        case TVBadgeType.success:
          return AppTheme.successColor.withValues(alpha: 0.1);
        case TVBadgeType.warning:
          return AppTheme.warningColor.withValues(alpha: 0.1);
        case TVBadgeType.error:
          return AppTheme.errorColor.withValues(alpha: 0.1);
        case TVBadgeType.neutral:
          return AppTheme.outlineColor.withValues(alpha: 0.4);
      }
    }

    Color getTextColor() {
      switch (type) {
        case TVBadgeType.success:
          return AppTheme.successColor;
        case TVBadgeType.warning:
          return const Color(0xFFB45309); // Darker amber for reading
        case TVBadgeType.error:
          return AppTheme.errorColor;
        case TVBadgeType.neutral:
          return AppTheme.textSecondaryColor;
      }
    }

    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: getTextColor()),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: getTextColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
