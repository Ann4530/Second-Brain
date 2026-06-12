import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/models/entry.dart';
import '../../data/models/reflection.dart';
import '../../data/services/on_device_ai_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../history/streak.dart';
import 'journal_controller.dart';

/// The day-one-value core loop: speak or type ~2 minutes → reflection + nudge.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _controller = TextEditingController();
  final _speech = SpeechToText();
  bool _sttReady = false;
  bool _listening = false;

  /// When true, force the composer even if today already has a saved entry
  /// (i.e. the user tapped "New entry").
  bool _composing = false;

  /// Return to the composer to write another entry.
  void _startNew() {
    _controller.clear();
    ref.read(journalControllerProvider.notifier).reset();
    setState(() => _composing = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (!_sttReady) {
      _sttReady = await _speech.initialize();
      if (!_sttReady) return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) => setState(() => _controller.text = r.recognizedWords),
      listenOptions:
          SpeechListenOptions(listenFor: const Duration(minutes: 3)),
    );
  }

  Future<void> _submit() async {
    await _speech.stop();
    setState(() => _listening = false);
    await ref.read(journalControllerProvider.notifier).submit(
          _controller.text,
          language: ref.read(reflectionLanguageProvider),
        );
    // Once submitted, drop "compose" mode so the new reflection is shown.
    if (mounted) setState(() => _composing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalControllerProvider);
    final todays = ref.watch(todaysEntryProvider);
    final theme = Theme.of(context);

    // If already journaled today, show that entry.
    final existing = todays.valueOrNull;

    final streak = ref.watch(streakProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text('🔥 $streak')),
            ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const _Reflecting(),
          error: (e, _) => _ErrorView(
            message: _friendlyError(e),
            onRetry: _startNew,
          ),
          data: (entry) {
            final shown = entry ?? existing;
            if (shown != null && !_composing) {
              return _ReflectionView(entry: shown, onNew: _startNew);
            }
            return _Composer(
              controller: _controller,
              listening: _listening,
              onMic: _toggleMic,
              onSubmit: _submit,
              hint: theme.textTheme.bodySmall,
            );
          },
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is DailyLimitReached) {
      return 'You\'ve used today\'s free reflection. Upgrade for unlimited.';
    }
    if (e is OnDeviceUnsupported) {
      return 'This device can\'t run the on-device AI. Turn off "on-device only" '
          'in Settings to use the private cloud, or try a device with more RAM.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.listening,
    required this.onMic,
    required this.onSubmit,
    this.hint,
  });

  final TextEditingController controller;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSubmit;
  final TextStyle? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How was your day?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Speak or type for ~2 minutes. Stays private on your phone.',
              style: hint),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Today I…',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onMic,
                iconSize: 28,
                icon: Icon(listening ? Icons.stop : Icons.mic),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSubmit,
                  child: const Text('Reflect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Reflecting extends StatelessWidget {
  const _Reflecting();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Reflecting…'),
        ],
      ),
    );
  }
}

class _ReflectionView extends StatelessWidget {
  const _ReflectionView({required this.entry, required this.onNew});
  final Entry entry;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reflection', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(entry.reflection, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.nudge)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('mood: ${entry.metadata.mood}')),
              Chip(label: Text('energy: ${entry.metadata.energy}/5')),
              for (final t in entry.metadata.topics.take(3)) Chip(label: Text(t)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.source == AiSource.onDevice
                ? '🔒 Generated on your device'
                : '☁️ Generated via private cloud',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('New entry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('OK')),
          ],
        ),
      ),
    );
  }
}
