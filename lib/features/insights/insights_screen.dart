import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/weekly_recap.dart';
import '../history/streak.dart';
import 'insights_controller.dart';
import 'share_card.dart';

/// Weekly "patterns about you" + the shareable Wrapped card (viral loop).
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(weeklyRecapProvider);
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: recap.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Finding your patterns…'),
            ],
          ),
        ),
        error: (e, _) => _Empty(
          icon: Icons.error_outline,
          title: 'Couldn\'t build your recap',
          body: '$e',
        ),
        data: (r) {
          if (r == null) {
            return const _Empty(
              icon: Icons.insights,
              title: 'Patterns about you',
              body: 'Journal at least 3 days this week and your patterns will '
                  'appear here — like "you\'re happiest on days you walk".',
            );
          }
          return _RecapView(recap: r, streak: streak);
        },
      ),
    );
  }
}

class _RecapView extends StatelessWidget {
  const _RecapView({required this.recap, required this.streak});
  final WeeklyRecap recap;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview of the shareable card.
          Center(child: ShareCard(recap: recap, streak: streak)),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.ios_share),
              label: const Text('Share my week'),
              onPressed: () => shareRecapCard(recap, streak),
            ),
          ),
          const SizedBox(height: 24),
          Text('This week\'s patterns', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(recap.narrative, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(
            'Avg mood ${recap.stats['avgMood'] ?? '-'} · '
            'energy ${recap.stats['avgEnergy'] ?? '-'} · '
            '${recap.stats['entryCount'] ?? 0} entries',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
