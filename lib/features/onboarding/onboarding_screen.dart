import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/prefs_repository.dart';
import '../../shared/widgets/em_primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(prefsRepositoryProvider).setOnboardingComplete();
              if (!context.mounted) return;
              context.go('/profile-setup');
            },
            child: const Text('Skip intro'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                _OnboardPage(
                  icon: Icons.bluetooth_searching,
                  title: 'No towers required',
                  body:
                      'EchoMesh uses Bluetooth Low Energy to find nearby operators and exchange short text when cellular service is gone.',
                ),
                _OnboardPage(
                  icon: Icons.shield_outlined,
                  title: 'Built for the field',
                  body:
                      'Keep a local profile, SOS presets, and encrypted-at-rest chat history on your device. Nothing is uploaded.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    2,
                    (i) => AnimatedContainer(
                      duration: 200.ms,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _i == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _i == i ? AppTheme.accent : AppTheme.outline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_i == 0)
                  EmPrimaryButton(
                    label: 'Continue',
                    onPressed: () => _page.nextPage(
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                  )
                else
                  EmPrimaryButton(
                    label: 'Configure profile',
                    onPressed: () async {
                      await ref.read(prefsRepositoryProvider).setOnboardingComplete();
                      if (!context.mounted) return;
                      context.go('/profile-setup');
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 52, color: AppTheme.accent)
              .animate()
              .fadeIn(duration: 400.ms)
              .moveY(begin: 12, end: 0),
          const SizedBox(height: 28),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.onSurfaceMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
