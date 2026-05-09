import 'dart:io';

import 'package:flutter/services.dart';

/// Android: native [EchoMeshBleHost] GATT server + advertising.
class BleHostPlatform {
  static const _method = MethodChannel('echomesh/ble_host');
  static const _events = EventChannel('echomesh/ble_host_events');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> start({required String displayName}) async {
    if (!isSupported) return false;
    final ok = await _method.invokeMethod<bool>('start', {'name': displayName});
    return ok ?? false;
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('stop');
  }

  static Future<void> notifyWire(String jsonPayload) async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('notify', {'payload': jsonPayload});
  }

  static Stream<String> incomingPayloads() {
    if (!isSupported) {
      return const Stream.empty();
    }
    return _events.receiveBroadcastStream().map((e) => e as String);
  }
}
