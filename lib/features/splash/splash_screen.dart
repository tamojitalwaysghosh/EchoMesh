import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/prefs_repository.dart';
import '../../repositories/profile_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final prefs = ref.read(prefsRepositoryProvider);
    final profile = ref.read(profileRepositoryProvider).profile;
    if (!prefs.onboardingComplete) {
      context.go('/onboarding');
      return;
    }
    if (profile == null ||
        profile.username.trim().isEmpty ||
        profile.meshId.isEmpty) {
      context.go('/profile-setup');
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/images/app-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: AppConstants.scanUiPulse,
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 28),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offline field link',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}
