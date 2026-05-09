import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/prefs_repository.dart';
import '../../services/echomesh_ble_notifier.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  String? _lastReadUpTo;
  int _lastMsgCount = 0;
  var _didInitialJump = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({required bool animated}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _scroll.jumpTo(target);
  }

  void _maybeAutoScrollToLatest({required bool animated}) {
    if (!_scroll.hasClients) return;
    final nearBottom = _scroll.position.extentAfter < 220;
    if (!nearBottom) return;
    _scrollToBottom(animated: animated);
  }

  String _peerTitle(PrefsRepository prefs) {
    final a = prefs.peerAliases[widget.threadId.toUpperCase()];
    if (a != null && a.isNotEmpty) return a;
    if (widget.threadId.length >= 8) return 'Peer ${widget.threadId.substring(0, 8)}';
    return 'Peer';
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatRepositoryProvider);
    final prefs = ref.watch(prefsRepositoryProvider);
    final ble = ref.watch(echomeshBleProvider);
    final title = _peerTitle(prefs);
    final avatarB64 = prefs.peerAvatarsBase64[widget.threadId.toUpperCase()];
    final fmtTime = DateFormat.jm();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: avatarB64 != null && avatarB64.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundImage: MemoryImage(base64Decode(avatarB64)),
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              ble.connectedRemoteId?.toUpperCase() == widget.threadId.toUpperCase()
                  ? 'Link active'
                  : 'Offline queue',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(echomeshBleProvider.notifier).disconnect();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected')));
            },
            child: const Text('Drop link'),
          ),
        ],
      ),
      body: StreamBuilder<void>(
        stream: chat.changes,
        builder: (context, _) {
          final msgs = chat.messagesFor(widget.threadId);
          final sig = msgs.isEmpty ? '' : '${msgs.length}_${msgs.last.id}_${msgs.last.sentAtMs}';
          if (sig != _lastReadUpTo) {
            _lastReadUpTo = sig;
            final lastTs = msgs.isEmpty ? 0 : msgs.last.sentAtMs;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chat.markThreadRead(widget.threadId, lastTs);
            });
            // Read receipt for latest incoming message in this thread.
            final lastIncoming = msgs.lastWhere(
              (m) => !m.isMine,
              orElse: () => const ChatMessage(
                id: '',
                threadId: '',
                text: '',
                sentAtMs: 0,
                isMine: true,
              ),
            );
            if (lastIncoming.id.isNotEmpty) {
              unawaited(
                ref
                    .read(echomeshBleProvider.notifier)
                    .sendReadReceipt(threadId: widget.threadId, messageId: lastIncoming.id),
              );
            }
          }
          if (msgs.length != _lastMsgCount) {
            final grew = msgs.length > _lastMsgCount;
            _lastMsgCount = msgs.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_didInitialJump) {
                _didInitialJump = true;
                // On first open, always show latest message (bottom).
                _scrollToBottom(animated: false);
                // Some devices report maxScrollExtent=0 on first frame; retry once.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(animated: false);
                });
              } else {
                _maybeAutoScrollToLatest(animated: grew);
              }
            });
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    return _Bubble(message: m, fmt: fmtTime);
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'SOS template',
                        onPressed: () {
                          _controller.text = AppConstants.sosDefaultMessage;
                        },
                        icon: Icon(Icons.crisis_alert_outlined, color: AppTheme.emergency),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Secure text — stays on device',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () async {
                          final t = _controller.text.trim();
                          if (t.isEmpty) return;
                          _controller.clear();
                          await ref.read(echomeshBleProvider.notifier).sendText(
                                threadId: widget.threadId,
                                text: t,
                                emergency: false,
                              );
                          // Force-scroll to show the sent bubble immediately.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToBottom(animated: true);
                          });
                        },
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.fmt});

  final ChatMessage message;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final emergency = message.isEmergency;
    final bg = emergency
        ? AppTheme.emergency.withValues(alpha: 0.22)
        : (mine ? AppTheme.accent.withValues(alpha: 0.18) : AppTheme.surfaceVariant);
    final border = emergency ? AppTheme.emergency.withValues(alpha: 0.7) : AppTheme.outline;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: mine ? const Radius.circular(4) : null,
            bottomLeft: mine ? null : const Radius.circular(4),
          ),
          border: Border.all(color: border),
          boxShadow: emergency ? AppConstants.subtleGlowRed : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emergency)
              Row(
                children: [
                  Icon(Icons.crisis_alert, size: 16, color: AppTheme.emergency),
                  const SizedBox(width: 6),
                  Text(
                    'EMERGENCY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.emergency,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                  ),
                ],
              ),
            if (emergency) const SizedBox(height: 6),
            Text(message.text, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmt.format(DateTime.fromMillisecondsSinceEpoch(message.sentAtMs)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceMuted),
                ),
                if (mine) ...[
                  const SizedBox(width: 8),
                  Icon(
                    message.delivered ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.read
                        ? AppTheme.accent
                        : (message.delivered ? AppTheme.onSurfaceMuted : AppTheme.onSurfaceMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.04, end: 0);
  }
}
