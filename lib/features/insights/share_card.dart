import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/weekly_recap.dart';

/// The branded, anonymized "Wrapped"-style card — the viral loop.
/// Never includes raw entry text; only the headline + a few stats.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.recap, required this.streak});

  final WeeklyRecap recap;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final topTopics =
        (recap.stats['topTopics'] as List?)?.cast<String>() ?? const [];
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.seed, Color(0xFF2E3192)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MY WEEK, REFLECTED',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text(
            recap.headline.isEmpty ? 'A week of showing up.' : recap.headline,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(children: [
            _Stat('🔥', '$streak-day streak'),
            const SizedBox(width: 16),
            _Stat('📝', '${recap.stats['entryCount'] ?? 0} entries'),
          ]),
          if (topTopics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in topTopics.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Second Brain',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              Text('🔒 private, on-device AI',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.label);
  final String emoji;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Renders the card off-screen and opens the share sheet.
Future<void> shareRecapCard(WeeklyRecap recap, int streak) async {
  final controller = ScreenshotController();
  final Uint8List png = await controller.captureFromWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        // Material ancestor so any Material widgets render correctly off-screen.
        child: Material(
          type: MaterialType.transparency,
          child: ShareCard(recap: recap, streak: streak),
        ),
      ),
    ),
    pixelRatio: 3,
  );
  await Share.shareXFiles(
    [XFile.fromData(png, name: 'my-week.png', mimeType: 'image/png')],
    text: 'My week, reflected — with Second Brain 🔒 (private, on-device AI)',
  );
}
