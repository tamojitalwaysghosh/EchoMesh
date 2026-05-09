import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const String appName = 'EchoMesh';
  static const String sosDefaultMessage =
      'SOS — NEED HELP\n'
      'I may have low/no network. Please respond if you receive this.\n'
      'If you can, share your status + location.';

  static const double radiusCard = 16;
  static const double radiusButton = 14;
  static const double padPage = 20;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration scanUiPulse = Duration(milliseconds: 1500);

  static const List<BoxShadow> subtleGlowRed = [
    BoxShadow(
      color: Color(0x33FF3B3B),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> subtleGlowCyan = [
    BoxShadow(
      color: Color(0x2221D4C8),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
}
