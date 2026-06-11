import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/on_device_ai_service.dart';
import '../../shared/providers/app_providers.dart';

/// 3 slides: what it does · privacy promise · streaks. On "Start journaling":
/// request notification permission, schedule the daily reminder, and download
/// the on-device model with a progress UI.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  double? _downloadProgress; // null = not downloading

  Future<void> _finish() async {
    // 1. Notifications — the habit loop.
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.scheduleDailyReminder();

    // 2. On-device model. Skip silently if the device can't run it (the AI
    //    router will use the cloud fallback instead).
    final onDevice = ref.read(onDeviceAiProvider);
    if (await onDevice.canRunOnDevice) {
      setState(() => _downloadProgress = 0);
      try {
        await onDevice.ensureModel(
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } on OnDeviceUnsupported {
        // fall through — cloud fallback covers it
      } catch (_) {
        // Download failed (offline?) — the user can still journal; the model
        // will retry on first reflection.
      }
      if (mounted) setState(() => _downloadProgress = null);
    }

    if (mounted) context.go(Routes.today);
  }

  static const _slides = [
    (
      icon: Icons.self_improvement,
      title: 'A 2-minute daily reflection',
      body: 'Speak or type about your day. Get a thoughtful reflection and one '
          'small nudge — instantly.',
    ),
    (
      icon: Icons.lock_outline,
      title: '100% private',
      body: 'The AI runs on your phone. Your journal never leaves your device.',
    ),
    (
      icon: Icons.local_fire_department_outlined,
      title: 'Build the habit',
      body: 'Keep your streak, and watch patterns about you emerge over time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 72),
                        const SizedBox(height: 24),
                        Text(s.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(s.body, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _downloadProgress != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: _downloadProgress),
                        const SizedBox(height: 8),
                        Text(
                          'Setting up your private AI… '
                          '${(_downloadProgress! * 100).round()}% '
                          '(one-time download)',
                        ),
                      ],
                    )
                  : FilledButton(
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _page.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut);
                        }
                      },
                      child: Text(last ? 'Start journaling' : 'Next'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
