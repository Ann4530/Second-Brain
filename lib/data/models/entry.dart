import 'entry_metadata.dart';
import 'reflection.dart';

/// One journal entry, stored at users/{uid}/entries/{id}.
///
/// `text` is the user's transcript/typed input (encrypted at rest before write).
class Entry {
  const Entry({
    required this.id,
    required this.createdAt,
    required this.localDate,
    required this.text,
    required this.reflection,
    required this.nudge,
    required this.metadata,
    this.source = AiSource.onDevice,
  });

  final String id;
  final DateTime createdAt;

  /// Local calendar date "YYYY-MM-DD" — used for the daily cap and streaks.
  final String localDate;

  final String text;
  final String reflection;
  final String nudge;
  final EntryMetadata metadata;
  final AiSource source;

  Entry copyWith({String? text}) => Entry(
        id: id,
        createdAt: createdAt,
        localDate: localDate,
        text: text ?? this.text,
        reflection: reflection,
        nudge: nudge,
        metadata: metadata,
        source: source,
      );

  factory Entry.fromReflection({
    required String id,
    required DateTime createdAt,
    required String localDate,
    required String text,
    required Reflection r,
  }) =>
      Entry(
        id: id,
        createdAt: createdAt,
        localDate: localDate,
        text: text,
        reflection: r.reflection,
        nudge: r.nudge,
        metadata: r.metadata,
        source: r.source,
      );

  factory Entry.fromJson(String id, Map<String, dynamic> json) => Entry(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAtMs'] as num?)?.toInt() ?? 0),
        localDate: (json['localDate'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        reflection: (json['reflection'] ?? '').toString(),
        nudge: (json['nudge'] ?? '').toString(),
        metadata: EntryMetadata.fromJson(
          (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        source: (json['source'] == 'cloud') ? AiSource.cloud : AiSource.onDevice,
      );

  Map<String, dynamic> toJson() => {
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'localDate': localDate,
        'text': text, // encrypt before write — see EntryRepository
        'reflection': reflection,
        'nudge': nudge,
        'metadata': metadata.toJson(),
        'source': source == AiSource.cloud ? 'cloud' : 'onDevice',
      };
}
