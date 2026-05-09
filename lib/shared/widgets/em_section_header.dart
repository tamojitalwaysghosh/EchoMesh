import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EmSectionHeader extends StatelessWidget {
  const EmSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.onSurfaceMuted,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
