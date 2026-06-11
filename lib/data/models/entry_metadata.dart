/// Structured metadata the AI extracts from each journal entry.
///
/// These are concrete fields so the weekly recap can compute real statistics
/// (e.g. "mood on walk-days vs not") with plain code — no LLM, no vector DB.
class EntryMetadata {
  const EntryMetadata({
    this.mood = 'neutral',
    this.moodScore = 0,
    this.energy = 3,
    this.topics = const [],
    this.people = const [],
    this.activities = const [],
  });

  /// Free-text mood label, e.g. "anxious", "content".
  final String mood;

  /// Normalized mood for aggregation, -3..+3.
  final int moodScore;

  /// Energy level, 1..5.
  final int energy;

  final List<String> topics;
  final List<String> people;
  final List<String> activities;

  /// The JSON schema the AI must fill. Kept small & flat for reliability on
  /// small on-device models. Use this with constrained decoding / function
  /// calling so output is always schema-valid.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'mood': {'type': 'string'},
      'moodScore': {'type': 'integer', 'minimum': -3, 'maximum': 3},
      'energy': {'type': 'integer', 'minimum': 1, 'maximum': 5},
      'topics': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'people': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'activities': {
        'type': 'array',
        'items': {'type': 'string'}
      },
    },
    'required': ['mood', 'moodScore', 'energy', 'topics', 'activities'],
  };

  factory EntryMetadata.fromJson(Map<String, dynamic> json) {
    // Tolerant: small on-device models sometimes return a comma-separated
    // string instead of an array (e.g. people: "family" or
    // activities: "walk, gym"). Accept both, and a single scalar.
    List<String> list(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      if (v is String) {
        return v
            .split(RegExp(r'[,;/]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return EntryMetadata(
      mood: (json['mood'] ?? 'neutral').toString(),
      moodScore: _asInt(json['moodScore'], 0).clamp(-3, 3),
      energy: _asInt(json['energy'], 3).clamp(1, 5),
      topics: list(json['topics']),
      people: list(json['people']),
      activities: list(json['activities']),
    );
  }

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'moodScore': moodScore,
        'energy': energy,
        'topics': topics,
        'people': people,
        'activities': activities,
      };

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }
}
