import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../models/reflection.dart';
import '../models/weekly_recap.dart';
import 'ai_service.dart';

/// Builds the weekly "patterns about you" recap:
/// 1. Deterministic stats computed in plain code (no AI, exact).
/// 2. AI writes only the narrative from those stats + short snippets.
class RecapService {
  RecapService({required AiService ai}) : _ai = ai;

  final AiService _ai;

  /// Compute stats over [entries] (expected: last 7-30 days).
  /// Exposed for unit testing.
  static Map<String, dynamic> computeStats(List<Entry> entries) {
    if (entries.isEmpty) return {};

    // Mood by weekday.
    final byWeekday = <int, List<int>>{};
    for (final e in entries) {
      byWeekday.putIfAbsent(e.createdAt.weekday, () => []).add(
            e.metadata.moodScore,
          );
    }
    final moodByWeekday = {
      for (final kv in byWeekday.entries)
        DateFormat.E().format(DateTime(2024, 1, kv.key)): // Mon=1..Sun=7
            _avg(kv.value).toStringAsFixed(2),
    };

    // Mood with vs without each activity (the "you're happiest when you walk"
    // engine). Only activities seen >= 2 times to avoid noise.
    final activityCount = <String, int>{};
    for (final e in entries) {
      for (final a in e.metadata.activities) {
        activityCount[a] = (activityCount[a] ?? 0) + 1;
      }
    }
    final moodByActivity = <String, Map<String, String>>{};
    for (final a in activityCount.keys.where((a) => activityCount[a]! >= 2)) {
      final withA = <int>[];
      final withoutA = <int>[];
      for (final e in entries) {
        (e.metadata.activities.contains(a) ? withA : withoutA)
            .add(e.metadata.moodScore);
      }
      if (withoutA.isNotEmpty) {
        moodByActivity[a] = {
          'with': _avg(withA).toStringAsFixed(2),
          'without': _avg(withoutA).toStringAsFixed(2),
        };
      }
    }

    // Top topics & people.
    Map<String, int> tally(Iterable<List<String>> lists) {
      final m = <String, int>{};
      for (final l in lists) {
        for (final x in l) {
          m[x] = (m[x] ?? 0) + 1;
        }
      }
      return m;
    }

    List<String> top(Map<String, int> m, int n) {
      final keys = m.keys.toList()
        ..sort((a, b) => m[b]!.compareTo(m[a]!));
      return keys.take(n).toList();
    }

    final topics = tally(entries.map((e) => e.metadata.topics));
    final people = tally(entries.map((e) => e.metadata.people));

    return {
      'entryCount': entries.length,
      'avgMood': _avg(entries.map((e) => e.metadata.moodScore).toList())
          .toStringAsFixed(2),
      'avgEnergy': _avg(entries.map((e) => e.metadata.energy).toList())
          .toStringAsFixed(2),
      'moodByWeekday': moodByWeekday,
      'moodByActivity': moodByActivity,
      'topTopics': top(topics, 5),
      'topPeople': top(people, 3),
    };
  }

  static double _avg(List<int> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  /// Build a recap for the period covered by [entries].
  /// `snippets` sent to the AI are short reflections (never raw entry text) —
  /// smaller, cheaper, and more private.
  Future<WeeklyRecap> build({
    required String id,
    required List<Entry> entries,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? language,
  }) async {
    final stats = computeStats(entries);
    final snippets = entries
        .take(10)
        .map((e) => e.reflection.length > 160
            ? e.reflection.substring(0, 160)
            : e.reflection)
        .toList();

    final n = await _ai.weeklyNarrative(
      stats: stats,
      snippets: snippets,
      language: language,
    );

    return WeeklyRecap(
      id: id,
      periodStart: periodStart,
      periodEnd: periodEnd,
      narrative: n.narrative,
      headline: n.headline,
      stats: stats,
      source: AiSource.onDevice, // router decides; display-only field
    );
  }
}
