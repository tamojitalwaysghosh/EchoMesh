import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Maps RSSI to 0–4 bars for tactical UI.
class EmSignalBars extends StatelessWidget {
  const EmSignalBars({super.key, required this.rssi, this.size = 18});

  final int rssi;
  final double size;

  int get _level {
    if (rssi >= -55) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    if (rssi >= -85) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final h = size;
    final active = AppTheme.accent;
    final dim = AppTheme.onSurfaceMuted.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final on = i < _level;
        final barH = h * (0.35 + (i + 1) * 0.18);
        return Container(
          width: 3,
          height: barH,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: on ? active : dim,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
