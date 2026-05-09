import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/echomesh_ble_notifier.dart';

class EchoMeshApp extends ConsumerStatefulWidget {
  const EchoMeshApp({super.key});

  @override
  ConsumerState<EchoMeshApp> createState() => _EchoMeshAppState();
}

class _EchoMeshAppState extends ConsumerState<EchoMeshApp> {
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(echomeshBleProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
