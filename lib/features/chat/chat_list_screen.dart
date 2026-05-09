import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../../core/theme/app_theme.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/prefs_repository.dart';
import '../../shared/widgets/em_card.dart';
import '../../shared/widgets/em_section_header.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatRepositoryProvider);
    final prefs = ref.watch(prefsRepositoryProvider);
    final fmt = DateFormat.MMMd().add_jm();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Message log')),
      body: StreamBuilder<void>(
        stream: chat.changes,
        builder: (context, _) {
          final threads = chat.recentThreads(peerNames: prefs.peerAliases);
          if (threads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Threads appear after you exchange traffic with a connected peer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.onSurfaceMuted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const EmSectionHeader(title: 'Conversations'),
              ...threads.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EmCard(
                    onTap: () => context.push('/chat', extra: t.peerId),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.surface,
                          backgroundImage: (() {
                            final b64 = prefs.peerAvatarsBase64[t.peerId.toUpperCase()];
                            if (b64 == null || b64.isEmpty) return null;
                            try {
                              return MemoryImage(base64Decode(b64));
                            } catch (_) {
                              return null;
                            }
                          })(),
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
                                  Text(
                                    fmt.format(DateTime.fromMillisecondsSinceEpoch(t.lastMessageMs)),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceMuted),
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
                        if (t.unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.accent.withValues(alpha: 0.25),
                              child: Text(
                                '${t.unreadCount}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
