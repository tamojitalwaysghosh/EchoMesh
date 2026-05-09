import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class EmPrimaryButton extends StatelessWidget {
  const EmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppTheme.emergency : AppTheme.accent;
    final fg = danger ? Colors.white : Colors.black;
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: onPressed == null ? fg.withValues(alpha: 0.4) : fg, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onPressed == null ? fg.withValues(alpha: 0.4) : fg,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusButton),
        ),
      ),
      onPressed: onPressed,
      child: expanded ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}
