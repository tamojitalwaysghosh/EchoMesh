import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Must match [com.example.bt_connect_chat.EchoMeshBleHost] on Android.
abstract final class EchoMeshBleUuids {
  static final Guid service = Guid('a1b2c3d4-e5f6-4790-abcd-ef1234567890');
  static final Guid rx = Guid('a1b2c3d4-e5f6-4790-abcd-ef1234567891');
  static final Guid tx = Guid('a1b2c3d4-e5f6-4790-abcd-ef1234567892');
}
