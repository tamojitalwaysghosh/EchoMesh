import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/prefs_repository.dart';
import '../../providers/profile_provider.dart';
import '../../services/echomesh_ble_notifier.dart';
import '../../shared/widgets/em_card.dart';
import '../../shared/widgets/em_primary_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  profile?.username ?? '—',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (profile?.emergencyInfo.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile!.emergencyInfo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
                  ),
                ],
                const SizedBox(height: 12),
                EmPrimaryButton(
                  label: 'Edit operator profile',
                  onPressed: () => context.push('/profile-setup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bluetooth', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'EchoMesh needs Bluetooth scan, connect, and (on Android) advertise permissions. '
                  'Location may be required on older Android versions for scanning.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted, height: 1.45),
                ),
                const SizedBox(height: 12),
                EmPrimaryButton(
                  label: 'Restart BLE host',
                  icon: Icons.refresh,
                  onPressed: () async {
                    final u = profile?.username ?? 'EchoMesh';
                    await ref.read(echomeshBleProvider.notifier).restartPeripheral(u);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host restarted')));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Danger zone', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.emergency)),
                const SizedBox(height: 8),
                Text(
                  'Clear cached peer aliases and last link metadata. Messages remain until manually cleared from storage.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
                ),
                const SizedBox(height: 12),
                EmPrimaryButton(
                  label: 'Forget last link',
                  danger: true,
                  onPressed: () async {
                    await ref.read(prefsRepositoryProvider).clearLastConnected();
                    await ref.read(echomeshBleProvider.notifier).disconnect();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last link cleared')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
