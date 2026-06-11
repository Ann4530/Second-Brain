import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/models/entry.dart';
import 'package:second_brain/data/models/entry_metadata.dart';
import 'package:second_brain/features/history/streak.dart';

Entry _entry(DateTime day, {int mood = 0, List<String> activities = const []}) {
  final localDate =
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return Entry(
    id: localDate,
    createdAt: day,
    localDate: localDate,
    text: 't',
    reflection: 'r',
    nudge: 'n',
    metadata: EntryMetadata(moodScore: mood, activities: activities),
  );
}

void main() {
  final today = DateTime(2026, 6, 10);

  group('computeStreak', () {
    test('empty → 0', () {
      expect(computeStreak([], today: today), 0);
    });

    test('journaled today + 2 prior days → 3', () {
      final entries = [
        _entry(today),
        _entry(today.subtract(const Duration(days: 1))),
        _entry(today.subtract(const Duration(days: 2))),
      ];
      expect(computeStreak(entries, today: today), 3);
    });

    test('not yet journaled today, streak through yesterday survives', () {
      final entries = [
        _entry(today.subtract(const Duration(days: 1))),
        _entry(today.subtract(const Duration(days: 2))),
      ];
      expect(computeStreak(entries, today: today), 2);
    });

    test('gap two days ago breaks streak', () {
      final entries = [
        _entry(today),
        _entry(today.subtract(const Duration(days: 2))), // gap at day-1? no:
      ];
      // today counted; day-1 missing → streak stops at 1
      expect(computeStreak(entries, today: today), 1);
    });

    test('last entry older than yesterday → 0', () {
      final entries = [_entry(today.subtract(const Duration(days: 3)))];
      expect(computeStreak(entries, today: today), 0);
    });

    test('duplicate same-day entries count once', () {
      final entries = [_entry(today), _entry(today)];
      expect(computeStreak(entries, today: today), 1);
    });
  });
}
