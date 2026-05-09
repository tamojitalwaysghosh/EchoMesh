import 'dart:convert';

class WirePayload {
  const WirePayload({
    required this.id,
    required this.senderId,
    required this.text,
    required this.ts,
    this.kind = 'msg',
    this.senderHandle,
    this.emergency = false,
    this.ackFor,
    this.ackType,
    this.avatarBase64,
  });

  final String id;
  final String senderId;
  final String text;
  final int ts;
  /// 'msg' | 'ack' | 'avatar'
  final String kind;
  final String? senderHandle;
  final bool emergency;
  /// For kind=='ack': message id being acked.
  final String? ackFor;
  /// For kind=='ack': 'delivered' | 'read'
  final String? ackType;
  /// For kind=='avatar': base64 encoded jpeg/png bytes.
  final String? avatarBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'ts': ts,
        'kind': kind,
        'emergency': emergency,
        if (senderHandle != null) 'senderHandle': senderHandle,
        if (ackFor != null) 'ackFor': ackFor,
        if (ackType != null) 'ackType': ackType,
        if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      };

  factory WirePayload.fromJson(Map<String, dynamic> j) {
    return WirePayload(
      id: j['id'] as String,
      senderId: j['senderId'] as String,
      text: j['text'] as String,
      ts: j['ts'] as int,
      kind: j['kind'] as String? ?? 'msg',
      senderHandle: j['senderHandle'] as String?,
      emergency: j['emergency'] as bool? ?? false,
      ackFor: j['ackFor'] as String?,
      ackType: j['ackType'] as String?,
      avatarBase64: j['avatarBase64'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static WirePayload? tryDecode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return WirePayload.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}
