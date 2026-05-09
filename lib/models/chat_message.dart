class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.text,
    required this.sentAtMs,
    required this.isMine,
    this.isEmergency = false,
    this.delivered = false,
    this.read = false,
  });

  final String id;
  final String threadId;
  final String text;
  final int sentAtMs;
  final bool isMine;
  final bool isEmergency;
  final bool delivered;
  final bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'threadId': threadId,
        'text': text,
        'sentAtMs': sentAtMs,
        'isMine': isMine,
        'isEmergency': isEmergency,
        'delivered': delivered,
        'read': read,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    return ChatMessage(
      id: j['id'] as String,
      threadId: j['threadId'] as String,
      text: j['text'] as String,
      sentAtMs: j['sentAtMs'] as int,
      isMine: j['isMine'] as bool,
      isEmergency: j['isEmergency'] as bool? ?? false,
      delivered: j['delivered'] as bool? ?? false,
      read: j['read'] as bool? ?? false,
    );
  }

  ChatMessage copyWith({
    bool? delivered,
    bool? read,
  }) {
    return ChatMessage(
      id: id,
      threadId: threadId,
      text: text,
      sentAtMs: sentAtMs,
      isMine: isMine,
      isEmergency: isEmergency,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
    );
  }
}
