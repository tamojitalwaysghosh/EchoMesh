import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';
import '../../services/echomesh_ble_notifier.dart';
import '../../services/permissions_service.dart';
import '../../shared/widgets/em_card.dart';
import '../../shared/widgets/em_primary_button.dart';
import '../../shared/widgets/em_signal_bars.dart';

class NearbyDevicesScreen extends ConsumerStatefulWidget {
  const NearbyDevicesScreen({super.key});

  @override
  ConsumerState<NearbyDevicesScreen> createState() =>
      _NearbyDevicesScreenState();
}

class _NearbyDevicesScreenState extends ConsumerState<NearbyDevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final ok = await PermissionsService.ensureBlePermissions();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permissions required for scan'),
        ),
      );
      return;
    }
    await ref.read(echomeshBleProvider.notifier).startScanning();
  }

  @override
  void dispose() {
    unawaited(FlutterBluePlus.stopScan());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(echomeshBleProvider);
    final sorted = List<ScanResult>.from(ble.scanResults)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    // Check if Bluetooth is off
    final bluetoothOff = !ble.adapterOn;
    final hasError = ble.linkError != null && ble.linkError!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nearby devices'),
        actions: [
          IconButton(
            icon: Icon(
              ble.scanning
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            onPressed: bluetoothOff
                ? null
                : () async {
                    if (ble.scanning) {
                      await ref
                          .read(echomeshBleProvider.notifier)
                          .stopScanning();
                    } else {
                      await _start();
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Show error banner if Bluetooth is off
          if (bluetoothOff)
            Container(
              width: double.infinity,
              color: Colors.red.withAlpha(25),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bluetooth_disabled, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bluetooth is off',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Turn on Bluetooth to discover and connect with nearby devices.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(echomeshBleProvider.notifier)
                            .openBluetoothSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Enable Bluetooth'),
                    ),
                  ),
                ],
              ),
            )
          else if (hasError && !ble.scanning)
            Container(
              width: double.infinity,
              color: Colors.orange.withAlpha(25),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ble.linkError!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _start();
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: EmCard(
              padding: const EdgeInsets.all(14),
              glow: ble.scanning,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ble.scanning
                        ? Lottie.asset(
                            'assets/lottie/pulse.json',
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            Icons.sensors_off,
                            color: AppTheme.onSurfaceMuted,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ble.scanning
                              ? 'Scanning for EchoMesh service'
                              : 'Scan paused',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sorted.length} radios in range',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty && !ble.scanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 48,
                          color: AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start scanning to find EchoMesh devices',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final r = sorted[i];
                      final name = r.device.advName.isNotEmpty
                          ? r.device.advName
                          : (r.device.platformName.isNotEmpty
                                ? r.device.platformName
                                : r.device.remoteId.str);
                      return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: EmCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      _SeenChip(
                                        lastSeenMs: ble.lastSeenMsById[
                                                r.device.remoteId.str
                                                    .toUpperCase()] ??
                                            0,
                                      ),
                                      EmSignalBars(rssi: r.rssi),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${r.rssi} dBm',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.device.remoteId.str,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.onSurfaceMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  EmPrimaryButton(
                                    label: ble.connecting
                                        ? 'Connecting…'
                                        : 'Connect',
                                    expanded: true,
                                    onPressed: ble.connecting
                                        ? null
                                        : () async {
                                            await ref
                                                .read(
                                                  echomeshBleProvider.notifier,
                                                )
                                                .connectTo(r);
                                            final s = ref.read(
                                              echomeshBleProvider,
                                            );
                                            if (s.connectedRemoteId != null &&
                                                context.mounted) {
                                              context.push(
                                                '/chat',
                                                extra: s.connectedRemoteId,
                                              );
                                            } else if (s.linkError != null &&
                                                context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(s.linkError!),
                                                ),
                                              );
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 220.ms, delay: (i * 40).ms)
                          .slideY(begin: 0.06, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeenChip extends StatelessWidget {
  const _SeenChip({required this.lastSeenMs});

  final int lastSeenMs;

  @override
  Widget build(BuildContext context) {
    if (lastSeenMs <= 0) return const SizedBox.shrink();
    final age = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    final secs = (age / 1000).round();
    final label = secs <= 2 ? 'Seen now' : 'Seen ${secs}s';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
