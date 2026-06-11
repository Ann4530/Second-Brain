import '../models/reflection.dart';

/// Shared interface implemented by both the on-device engine and the cloud
/// (Groq) engine, so the rest of the app is engine-agnostic.
abstract interface class AiService {
  /// Produce a reflection + nudge + structured metadata for one entry.
  Future<Reflection> reflect(String entryText, {String? language});

  /// Write the AI narrative for a weekly recap given precomputed stats and a
  /// few short entry snippets. Returns (headline, narrative).
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
  });
}

/// Shared prompt fragments. The persona is the stable prefix (good for caching
/// on cloud; consistent tone on device). Keep it warm but never clinical.
class AiPrompts {
  AiPrompts._();

  static const String persona = '''
You are a warm, perceptive reflection companion inside a private journaling app.
Given a short journal entry, you:
1) Write a brief (2-4 sentence) reflection that mirrors the person's feelings and
   gently surfaces one insight. Be specific to what they wrote. Never generic.
2) Offer ONE small, concrete, doable nudge for tomorrow.
You are NOT a therapist; never diagnose. Be kind, honest, and concise.
''';

  static String reflectInstruction(String entry, {String? language}) => '''
$persona

${language != null ? 'Respond in: $language.\n' : ''}
Journal entry:
"""
$entry
"""

Return ONLY a JSON object with this exact shape:
{
  "reflection": "string",
  "nudge": "string",
  "metadata": {
    "mood": "string", "moodScore": -3..3, "energy": 1..5,
    "topics": ["string"], "people": ["string"], "activities": ["string"]
  }
}
''';

  static String weeklyInstruction(
          Map<String, dynamic> stats, List<String> snippets) =>
      '''
$persona

Here are this period's computed stats about the person:
$stats

And a few short snippets from their entries:
${snippets.map((s) => '- $s').join('\n')}

Write "patterns about you": surface 2-3 genuine, specific patterns (e.g. tie mood
to activities/weekdays). Then ONE forward-looking nudge.

Return ONLY JSON:
{ "headline": "one punchy line (<=90 chars) for a shareable card",
  "narrative": "2-4 short paragraphs" }
''';
}
