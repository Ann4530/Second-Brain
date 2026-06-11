import 'package:cloud_functions/cloud_functions.dart';

import '../models/reflection.dart';
import 'ai_service.dart';

/// FALLBACK / premium engine: calls a Firebase Cloud Function that proxies
/// Groq (Llama 3.3 70B, zero data retention). The Groq API key lives in the
/// Function config — NEVER in the app.
///
/// Used for: low-RAM/unsupported devices, and high-quality premium weekly
/// recaps. Disabled entirely when the user enables "on-device only" mode.
class GroqAiService implements AiService {
  GroqAiService({FirebaseFunctions? functions}) : _override = functions;

  final FirebaseFunctions? _override;

  /// Lazy: only touches FirebaseFunctions.instance when the cloud path is
  /// actually invoked. Constructing this service must NOT require Firebase to
  /// be initialized (it's built eagerly at startup even when on-device is used).
  FirebaseFunctions get _functions => _override ?? FirebaseFunctions.instance;

  @override
  Future<Reflection> reflect(String entryText, {String? language}) async {
    final callable = _functions.httpsCallable('groqReflect');
    final res = await callable.call<Map<String, dynamic>>({
      'text': entryText,
      if (language != null) 'language': language,
    });
    return Reflection.fromJson(
      Map<String, dynamic>.from(res.data),
      source: AiSource.cloud,
    );
  }

  @override
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
  }) async {
    final callable = _functions.httpsCallable('groqWeeklyNarrative');
    final res = await callable.call<Map<String, dynamic>>({
      'stats': stats,
      'snippets': snippets,
    });
    final data = Map<String, dynamic>.from(res.data);
    return (
      headline: (data['headline'] ?? '').toString(),
      narrative: (data['narrative'] ?? '').toString(),
    );
  }
}
