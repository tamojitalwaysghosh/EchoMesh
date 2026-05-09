import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/prefs_repository.dart';
import '../../services/echomesh_ble_notifier.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/em_primary_button.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  var _fired = false;

  Future<void> _pulse() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 120, amplitude: 255);
      await Future<void>.delayed(const Duration(milliseconds: 160));
      await Vibration.vibrate(duration: 200, amplitude: 255);
    }
  }

  Future<void> _send() async {
    setState(() => _fired = true);
    await _pulse();
    final prefs = ref.read(prefsRepositoryProvider);
    final peer =
        prefs.lastConnectedRemoteId ?? ref.read(echomeshBleProvider).connectedRemoteId;
    if (peer == null || peer.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recent peer — connect from Nearby first')),
        );
      }
      return;
    }
    var msg = AppConstants.sosDefaultMessage;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        await Geolocator.openLocationSettings();
      }
      final perm = await Geolocator.checkPermission();
      var p = perm;
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (_) {
          // Retry once after opening location settings.
          await Geolocator.openLocationSettings();
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
        }
        msg = '$msg\n\nLocation: ${pos.latitude}, ${pos.longitude}';
      }
    } catch (e) {
      // Send SOS even if location fails, but log details for debugging.
      debugPrint('SOS location attach failed: $e');
    }
    await ref.read(echomeshBleProvider.notifier).sendText(
          threadId: peer,
          text: msg,
          emergency: true,
        );
    unawaited(NotificationService.notify(
      title: 'SOS sent',
      body: 'Emergency packet queued/sent',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS packet queued / sent on link')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.emergency.withValues(alpha: 0.8), width: 3),
                    boxShadow: AppConstants.subtleGlowRed,
                  ),
                  child: Material(
                    color: AppTheme.emergency.withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _fired ? null : _send,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crisis_alert, size: 64, color: AppTheme.emergency),
                            const SizedBox(height: 12),
                            Text(
                              'BROADCAST SOS',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.emergency,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: 900.ms,
                      begin: const Offset(0.94, 0.94),
                      end: const Offset(1, 1),
                      curve: Curves.easeInOut,
                    ),
              ),
            ),
            Text(
              AppConstants.sosDefaultMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 20),
            EmPrimaryButton(
              label: _fired ? 'Dispatched' : 'Send SOS now',
              danger: true,
              icon: Icons.bolt,
              onPressed: _fired ? null : _send,
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
