import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/prefs_repository.dart';
import '../../providers/profile_provider.dart';
import '../../services/echomesh_ble_notifier.dart';
import '../../services/permissions_service.dart';
import '../../shared/widgets/em_card.dart';
import '../../shared/widgets/em_primary_button.dart';
import '../../shared/widgets/em_section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final ble = ref.watch(echomeshBleProvider);
    final prefs = ref.watch(prefsRepositoryProvider);
    final chatRepo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.padPage),
        children: [
          EmCard(
            glow: ble.adapterOn,
            child: Row(
              children: [
                _StatusDot(on: ble.adapterOn),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ble.adapterOn ? 'Bluetooth ready' : 'Bluetooth unavailable',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ble.hostingActive
                            ? 'Discoverable as EchoMesh host'
                            : 'Host mode inactive (check permissions)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EmCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearby', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceMuted)),
                      const SizedBox(height: 6),
                      Text(
                        '${ble.scanResults.length}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text('EchoMesh radios', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EmCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurfaceMuted)),
                      const SizedBox(height: 6),
                      Text(
                        ble.connectedRemoteId != null ? 'Active' : 'Idle',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        ble.connecting ? 'Negotiating…' : (ble.connectedRemoteId ?? 'No peer'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (ble.linkError != null) ...[
            const SizedBox(height: 12),
            Text(ble.linkError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.emergency)),
          ],
          const SizedBox(height: 20),
          EmPrimaryButton(
            label: 'SOS — emergency ping',
            icon: Icons.crisis_alert_outlined,
            danger: true,
            onPressed: () => context.push('/sos'),
          ).animate().shimmer(duration: 2500.ms, color: Colors.white12),
          const SizedBox(height: 20),
          EmSectionHeader(
            title: 'Field actions',
            action: TextButton(
              onPressed: () async {
                await PermissionsService.ensureBlePermissions();
                if (context.mounted) context.push('/nearby');
              },
              child: const Text('Scan'),
            ),
          ),
          _HomeActionTile(
            icon: Icons.radar,
            title: 'Nearby devices',
            subtitle: 'Locate EchoMesh operators',
            onTap: () async {
              await PermissionsService.ensureBlePermissions();
              if (context.mounted) context.push('/nearby');
            },
          ),
          _HomeActionTile(
            icon: Icons.forum_outlined,
            title: 'Message log',
            subtitle: 'Local encrypted-at-rest history',
            onTap: () => context.push('/chats'),
          ),
          const SizedBox(height: 8),
          EmSectionHeader(title: 'Recent threads'),
          StreamBuilder<void>(
            stream: chatRepo.changes,
            builder: (context, _) {
              final threads = chatRepo.recentThreads(peerNames: prefs.peerAliases).take(4).toList();
              if (threads.isEmpty) {
                return Text(
                  'No conversations yet. Scan and connect to open a thread.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceMuted),
                );
              }
              return Column(
                children: threads
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EmCard(
                          onTap: () => context.push('/chat', extra: t.peerId),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.surface,
                                child: Text(t.peerName.isNotEmpty ? t.peerName[0].toUpperCase() : '?'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.peerName,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        if (t.unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${t.unreadCount}',
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.accent),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.lastPreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          if (profile != null)
            Text(
              'Signed in locally as ${profile.username}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? AppTheme.accent : AppTheme.emergency,
        boxShadow: [
          BoxShadow(
            color: (on ? AppTheme.accent : AppTheme.emergency).withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EmCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}
