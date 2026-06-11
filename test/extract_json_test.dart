import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/data/services/on_device_ai_service.dart';

void main() {
  group('OnDeviceAiService.extractJson', () {
    test('parses a clean JSON object', () {
      final j = OnDeviceAiService.extractJson('{"a": 1, "b": "x"}');
      expect(j['a'], 1);
      expect(j['b'], 'x');
    });

    test('strips prose and code fences around the object', () {
      const raw = 'Sure! Here is the JSON:\n```json\n'
          '{"reflection": "good day", "nudge": "walk"}\n```\nHope it helps!';
      final j = OnDeviceAiService.extractJson(raw);
      expect(j['reflection'], 'good day');
      expect(j['nudge'], 'walk');
    });

    test('handles nested objects (metadata)', () {
      const raw = 'x {"reflection":"r","metadata":{"mood":"calm","topics":["a"]}} y';
      final j = OnDeviceAiService.extractJson(raw);
      expect((j['metadata'] as Map)['mood'], 'calm');
    });

    test('braces inside strings do not break matching', () {
      const raw = '{"reflection": "I thought {hard} today", "nudge": "rest"}';
      final j = OnDeviceAiService.extractJson(raw);
      expect(j['reflection'], 'I thought {hard} today');
    });

    test('no JSON → empty map', () {
      expect(OnDeviceAiService.extractJson('no json here'), isEmpty);
    });

    test('malformed JSON → empty map (caller retries / falls back)', () {
      expect(OnDeviceAiService.extractJson('{"a": }'), isEmpty);
    });
  });
}
