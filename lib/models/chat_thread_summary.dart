class ChatThreadSummary {
  const ChatThreadSummary({
    required this.peerId,
    required this.peerName,
    required this.lastPreview,
    required this.lastMessageMs,
    required this.unreadCount,
  });

  final String peerId;
  final String peerName;
  final String lastPreview;
  final int lastMessageMs;
  final int unreadCount;
}
