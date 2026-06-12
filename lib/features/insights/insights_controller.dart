import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/weekly_recap.dart';
import '../../data/services/recap_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';

final recapServiceProvider = Provider<RecapService>(
  (ref) => RecapService(ai: ref.watch(aiServiceProvider)),
);

/// Generates (or regenerates) this week's recap from the last 7 days of
/// entries. Needs >= 3 entries to say anything meaningful.
final weeklyRecapProvider = FutureProvider<WeeklyRecap?>((ref) async {
  final service = ref.watch(recapServiceProvider);

  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 7));
  final entries = (await ref.watch(allEntriesProvider.future))
      .where((e) => e.createdAt.isAfter(start))
      .toList();

  if (entries.length < 3) return null; // not enough signal yet

  final weekId = '${now.year}-W${_isoWeek(now)}';
  return service.build(
    id: weekId,
    entries: entries,
    periodStart: start,
    periodEnd: now,
    language: ref.watch(reflectionLanguageProvider),
  );
});

int _isoWeek(DateTime d) {
  final dayOfYear = int.parse(DateFormat('D').format(d));
  final week = ((dayOfYear - d.weekday + 10) / 7).floor();
  if (week < 1) return 52;
  if (week > 52) return 1;
  return week;
}
