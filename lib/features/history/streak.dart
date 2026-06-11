import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/entry.dart';
import '../../shared/providers/app_providers.dart';

/// Current streak = consecutive localDates ending today or yesterday.
/// (Yesterday still counts so the streak isn't "broken" before the user has
/// had a chance to journal today.)
int computeStreak(List<Entry> entries, {DateTime? today}) {
  if (entries.isEmpty) return 0;
  final dates = entries.map((e) => e.localDate).toSet();
  final fmt = DateFormat('yyyy-MM-dd');
  var day = today ?? DateTime.now();

  // Anchor: today if journaled today, else yesterday.
  if (!dates.contains(fmt.format(day))) {
    day = day.subtract(const Duration(days: 1));
    if (!dates.contains(fmt.format(day))) return 0;
  }

  var streak = 0;
  while (dates.contains(fmt.format(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Milestones that trigger a celebratory shareable card.
const streakMilestones = [7, 30, 100, 365];

final streakProvider = FutureProvider<int>((ref) async {
  final entries = await ref.watch(allEntriesProvider.future);
  return computeStreak(entries);
});
