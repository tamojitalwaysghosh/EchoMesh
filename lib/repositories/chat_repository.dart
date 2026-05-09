import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/chat_thread_summary.dart';
import '../services/storage/hive_box_provider.dart';

class ChatRepository {
  ChatRepository(this._box);

  final Box<String> _box;
  final _uuid = const Uuid();
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }

  static String _messagesKey(String threadId) => 'messages_${threadId.toUpperCase()}';
  static const _kReadPrefix = 'read_ts_';

  List<ChatMessage> messagesFor(String threadId) {
    final raw = _box.get(_messagesKey(threadId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.sentAtMs.compareTo(b.sentAtMs));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMessages(String threadId, List<ChatMessage> list) async {
    final encoded = jsonEncode(list.map((m) => m.toJson()).toList());
    await _box.put(_messagesKey(threadId), encoded);
  }

  Future<ChatMessage> addOutgoing({
    required String threadId,
    required String text,
    required bool emergency,
    bool delivered = false,
  }) async {
    final list = messagesFor(threadId);
    final msg = ChatMessage(
      id: _uuid.v4(),
      threadId: threadId,
      text: text,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      isMine: true,
      isEmergency: emergency,
      delivered: delivered,
      // For outgoing messages, `read` means "read by peer".
      read: false,
    );
    list.add(msg);
    await _saveMessages(threadId, list);
    _emit();
    return msg;
  }

  Future<void> markDelivered(String threadId, String messageId) async {
    final list = messagesFor(threadId);
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(delivered: true);
    await _saveMessages(threadId, list);
    _emit();
  }

  Future<void> markReadByPeer(String threadId, String messageId) async {
    final list = messagesFor(threadId);
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(read: true, delivered: true);
    await _saveMessages(threadId, list);
    _emit();
  }

  Future<ChatMessage> addIncoming({
    required String threadId,
    required String text,
    required bool emergency,
    required String wireMessageId,
  }) async {
    final list = messagesFor(threadId);
    if (list.any((m) => m.id == wireMessageId)) {
      return list.firstWhere((m) => m.id == wireMessageId);
    }
    final msg = ChatMessage(
      id: wireMessageId,
      threadId: threadId,
      text: text,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      isMine: false,
      isEmergency: emergency,
      delivered: true,
      read: false,
    );
    list.add(msg);
    await _saveMessages(threadId, list);
    _emit();
    return msg;
  }

  int lastReadMs(String threadId) {
    final v = _box.get('$_kReadPrefix${threadId.toUpperCase()}');
    return int.tryParse(v ?? '') ?? 0;
  }

  Future<void> markThreadRead(String threadId, int upToMs) async {
    await _box.put('$_kReadPrefix${threadId.toUpperCase()}', '$upToMs');
    final list = messagesFor(threadId);
    var changed = false;
    final next = list.map((m) {
      if (!m.isMine && m.sentAtMs <= upToMs && !m.read) {
        changed = true;
        return m.copyWith(read: true);
      }
      return m;
    }).toList();
    if (changed) {
      await _saveMessages(threadId, next);
      _emit();
    }
  }

  List<ChatThreadSummary> recentThreads({required Map<String, String> peerNames}) {
    final keys = _box.keys.whereType<String>().where((k) => k.startsWith('messages_'));
    final summaries = <ChatThreadSummary>[];
    for (final k in keys) {
      final threadId = k.substring('messages_'.length);
      final msgs = messagesFor(threadId);
      if (msgs.isEmpty) continue;
      final last = msgs.last;
      final unread = msgs.where((m) => !m.isMine && !m.read).length;
      summaries.add(
        ChatThreadSummary(
          peerId: threadId,
          peerName: peerNames[threadId.toUpperCase()] ?? _friendlyPeerName(threadId),
          lastPreview: last.text,
          lastMessageMs: last.sentAtMs,
          unreadCount: unread,
        ),
      );
    }
    summaries.sort((a, b) => b.lastMessageMs.compareTo(a.lastMessageMs));
    return summaries;
  }

  String _friendlyPeerName(String threadId) {
    if (threadId.length >= 8) return 'Peer ${threadId.substring(0, 8)}';
    return 'Peer';
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository(ref.watch(hiveBoxProvider));
  ref.onDispose(repo.dispose);
  return repo;
});
