import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/models/entry_metadata.dart';

void main() {
  group('EntryMetadata.fromJson tolerance (small on-device models drift)', () {
    test('arrays parse normally', () {
      final m = EntryMetadata.fromJson({
        'mood': 'content',
        'moodScore': 2,
        'energy': 4,
        'topics': ['work', 'health'],
        'people': ['Sarah'],
        'activities': ['walk', 'gym'],
      });
      expect(m.mood, 'content');
      expect(m.topics, ['work', 'health']);
      expect(m.activities, ['walk', 'gym']);
    });

    test('comma-separated STRING (real Qwen output) → list', () {
      // Observed on-device: people: "family", activities: "walk, exercise, journaling"
      final m = EntryMetadata.fromJson({
        'mood': 5, // number instead of string
        'moodScore': 2,
        'energy': 4,
        'topics': ['work', 'well-being'],
        'people': 'family',
        'activities': 'walk, exercise, journaling, gratitude',
      });
      expect(m.mood, '5'); // coerced to string, no crash
      expect(m.people, ['family']);
      expect(m.activities, ['walk', 'exercise', 'journaling', 'gratitude']);
    });

    test('moodScore/energy clamp to valid ranges', () {
      final m = EntryMetadata.fromJson({'moodScore': 99, 'energy': 0});
      expect(m.moodScore, 3);
      expect(m.energy, 1);
    });

    test('moodScore as string parses', () {
      final m = EntryMetadata.fromJson({'moodScore': '-2'});
      expect(m.moodScore, -2);
    });

    test('missing/empty fields fall back safely', () {
      final m = EntryMetadata.fromJson({});
      expect(m.mood, 'neutral');
      expect(m.topics, isEmpty);
      expect(m.people, isEmpty);
    });

    test('semicolon/slash separators also split', () {
      final m = EntryMetadata.fromJson({'topics': 'a; b / c'});
      expect(m.topics, ['a', 'b', 'c']);
    });
  });
}
