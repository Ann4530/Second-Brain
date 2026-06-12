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

class _RecapView extends StatefulWidget {
  const _RecapView({required this.recap, required this.streak});
  final WeeklyRecap recap;
  final int streak;

  @override
  State<_RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<_RecapView> {
  String? _headline; // user edits (override the AI text)
  String? _narrative;

  /// The recap with the user's edits applied (used for display AND sharing).
  WeeklyRecap get _effective =>
      widget.recap.copyWith(headline: _headline, narrative: _narrative);

  Future<void> _edit() async {
    final current = _effective;
    final hCtrl = TextEditingController(text: current.headline);
    final nCtrl = TextEditingController(text: current.narrative);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit My Week'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hCtrl,
                maxLength: 90,
                decoration: const InputDecoration(
                  labelText: 'Headline',
                  helperText: 'The big line on the share card',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nCtrl,
                maxLines: 8,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Patterns',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      setState(() {
        _headline = hCtrl.text.trim();
        _narrative = nCtrl.text.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recap = _effective;
    final streak = widget.streak;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview of the shareable card.
          Center(child: ShareCard(recap: recap, streak: streak)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share my week'),
                  onPressed: () => shareRecapCard(recap, streak),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
                onPressed: _edit,
              ),
            ],
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
