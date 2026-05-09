import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class EmCard extends StatelessWidget {
  const EmCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    this.glowColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool glow;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final c = glowColor ?? AppTheme.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            border: Border.all(color: AppTheme.outline),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: c.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
