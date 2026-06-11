import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/models/entry.dart';
import 'package:second_brain/data/models/entry_metadata.dart';
import 'package:second_brain/data/services/recap_service.dart';

Entry _entry(DateTime day, {int mood = 0, List<String> activities = const []}) {
  return Entry(
    id: day.toIso8601String(),
    createdAt: day,
    localDate: day.toIso8601String().substring(0, 10),
    text: 't',
    reflection: 'r',
    nudge: 'n',
    metadata: EntryMetadata(moodScore: mood, activities: activities),
  );
}

void main() {
  group('RecapService.computeStats', () {
    test('empty → empty map', () {
      expect(RecapService.computeStats([]), isEmpty);
    });

    test('mood-by-activity surfaces the walk effect', () {
      final base = DateTime(2026, 6, 8);
      final entries = [
        _entry(base, mood: 2, activities: ['walk']),
        _entry(base.add(const Duration(days: 1)), mood: 3, activities: ['walk']),
        _entry(base.add(const Duration(days: 2)), mood: -1),
        _entry(base.add(const Duration(days: 3)), mood: 0),
      ];
      final stats = RecapService.computeStats(entries);
      final byActivity = stats['moodByActivity'] as Map<String, dynamic>;
      expect(byActivity.containsKey('walk'), isTrue);
      final walk = byActivity['walk'] as Map<String, String>;
      expect(double.parse(walk['with']!), greaterThan(double.parse(walk['without']!)));
    });

    test('activities seen once are excluded (noise filter)', () {
      final base = DateTime(2026, 6, 8);
      final entries = [
        _entry(base, mood: 2, activities: ['skydiving']),
        _entry(base.add(const Duration(days: 1)), mood: 0),
        _entry(base.add(const Duration(days: 2)), mood: 0),
      ];
      final stats = RecapService.computeStats(entries);
      final byActivity = stats['moodByActivity'] as Map<String, dynamic>;
      expect(byActivity.containsKey('skydiving'), isFalse);
    });

    test('entryCount and avgMood are correct', () {
      final base = DateTime(2026, 6, 8);
      final entries = [
        _entry(base, mood: 1),
        _entry(base.add(const Duration(days: 1)), mood: 3),
      ];
      final stats = RecapService.computeStats(entries);
      expect(stats['entryCount'], 2);
      expect(stats['avgMood'], '2.00');
    });
  });
}
