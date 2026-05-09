import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/storage/hive_box_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>(kHiveBoxName);

  runApp(
    ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(box),
      ],
      child: const EchoMeshApp(),
    ),
  );
}
