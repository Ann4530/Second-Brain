import 'reflection.dart';

/// A weekly/monthly "patterns about you" recap, stored at
/// users/{uid}/recaps/{weekId}.
///
/// `stats` are computed by plain code (mood by weekday, mood delta with/without
/// an activity, etc.); `narrative` is the AI-written summary of those stats.
class WeeklyRecap {
  const WeeklyRecap({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.narrative,
    required this.headline,
    required this.stats,
    this.source = AiSource.onDevice,
  });

  final String id; // e.g. "2026-W24" or "2026-06"
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Long-form "patterns about you".
  final String narrative;

  /// One-line punchy summary used on the shareable card.
  final String headline;

  /// Deterministic aggregates (avgMoodByWeekday, topTopics, streak, ...).
  final Map<String, dynamic> stats;

  final AiSource source;

  factory WeeklyRecap.fromJson(String id, Map<String, dynamic> json) =>
      WeeklyRecap(
        id: id,
        periodStart: DateTime.fromMillisecondsSinceEpoch(
            (json['periodStartMs'] as num?)?.toInt() ?? 0),
        periodEnd: DateTime.fromMillisecondsSinceEpoch(
            (json['periodEndMs'] as num?)?.toInt() ?? 0),
        narrative: (json['narrative'] ?? '').toString(),
        headline: (json['headline'] ?? '').toString(),
        stats: (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
        source:
            (json['source'] == 'cloud') ? AiSource.cloud : AiSource.onDevice,
      );

  Map<String, dynamic> toJson() => {
        'periodStartMs': periodStart.millisecondsSinceEpoch,
        'periodEndMs': periodEnd.millisecondsSinceEpoch,
        'narrative': narrative,
        'headline': headline,
        'stats': stats,
        'source': source == AiSource.cloud ? 'cloud' : 'onDevice',
      };
}
