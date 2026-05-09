import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _opsChannel =
      AndroidNotificationChannel(
    'echomesh_ops',
    'EchoMesh operations',
    description: 'Connection and message alerts for field use.',
    importance: Importance.max,
  );

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_opsChannel);

    // Android 13+ runtime permission.
    await android?.requestNotificationsPermission();
  }

  static Future<void> notify({
    required String title,
    required String body,
    int? id,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _opsChannel.id,
          _opsChannel.name,
          channelDescription: _opsChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}

