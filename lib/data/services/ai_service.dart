import '../models/chat_message.dart';
import '../models/reflection.dart';

/// Shared interface implemented by both the on-device engine and the cloud
/// (Groq) engine, so the rest of the app is engine-agnostic.
abstract interface class AiService {
  /// Produce a reflection + nudge + structured metadata for one entry.
  Future<Reflection> reflect(String entryText, {String? language});

  /// Return the AI's next conversational reply (plain text, not JSON) given
  /// the conversation history so far.
  Future<String> chat(List<ChatMessage> history, {String? language});

  /// Write the AI narrative for a weekly recap given precomputed stats and a
  /// few short entry snippets. Returns (headline, narrative).
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
    String? language,
  });
}

/// Shared prompt fragments.
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

  static const String conversationPersona = '''
You are a warm, curious journaling companion inside a private app.
Your role: have a brief, meaningful conversation to help the person reflect on their day.
- Ask ONE short follow-up question per turn. ONE sentence only, max ~15 words.
- Be warm and natural, like a close friend texting. No long paragraphs.
- Do not repeat or echo what they said back to them. Just ask the next question.
- Never diagnose. Never lecture.
''';

  /// Opening message shown to the user before any AI call (no API needed).
  static String openingQuestion(String? language) {
    if (language == 'English') return 'How\'s your day going? 😊';
    return 'Hôm nay của bạn như thế nào? 😊';
  }

  /// Prompt for a conversation turn — AI returns plain text (not JSON).
  static String chatInstruction(
    List<ChatMessage> history, {
    String? language,
  }) {
    final historyText = history
        .map((m) => '${m.isUser ? "User" : "AI"}: ${m.text}')
        .join('\n');
    return '''
$conversationPersona
${language != null ? 'Respond in: $language.\n' : ''}
Conversation so far:
$historyText

Continue the conversation. Ask one thoughtful follow-up question.
Return ONLY the reply text — no JSON, no quotes, no labels.
''';
  }

  /// Format a conversation history as a single entry text for reflect().
  static String conversationToEntryText(List<ChatMessage> history) {
    return history
        .map((m) => '${m.isUser ? "Tôi" : "AI"}: ${m.text}')
        .join('\n');
  }

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
    Map<String, dynamic> stats,
    List<String> snippets, {
    String? language,
  }) =>
      '''
$persona

Here are this period's computed stats about the person:
$stats

And a few short snippets from their entries:
${snippets.map((s) => '- $s').join('\n')}

Write "patterns about you": surface 2-3 genuine, specific patterns (e.g. tie mood
to activities/weekdays). Then ONE forward-looking nudge.

${language != null ? 'Write the headline and narrative in: $language.' : 'Write the headline and narrative in the SAME language as the snippets above.'}

Return ONLY JSON:
{ "headline": "one punchy line (<=90 chars) for a shareable card",
  "narrative": "2-4 short paragraphs" }
''';
}
