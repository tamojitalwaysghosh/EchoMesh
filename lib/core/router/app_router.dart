import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_room_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/nearby/nearby_devices_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sos/sos_screen.dart';
import '../../features/splash/splash_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/nearby',
        builder: (context, state) => const NearbyDevicesScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final id = state.extra as String? ?? '';
          return ChatRoomScreen(threadId: id);
        },
      ),
      GoRoute(
        path: '/sos',
        builder: (context, state) => const SosScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
