import 'entry_metadata.dart';

/// The AI's response to a single journal entry: a reflection + one nudge,
/// plus the structured metadata extracted in the same pass.
class Reflection {
  const Reflection({
    required this.reflection,
    required this.nudge,
    required this.metadata,
    this.source = AiSource.onDevice,
  });

  final String reflection;
  final String nudge;
  final EntryMetadata metadata;

  /// Which engine produced this (for analytics / privacy display).
  final AiSource source;

  factory Reflection.fromJson(Map<String, dynamic> json,
      {AiSource source = AiSource.onDevice}) {
    return Reflection(
      reflection: (json['reflection'] ?? '').toString(),
      nudge: (json['nudge'] ?? '').toString(),
      metadata: EntryMetadata.fromJson(
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
        'reflection': reflection,
        'nudge': nudge,
        'metadata': metadata.toJson(),
      };
}

/// Where a reflection/recap was generated.
enum AiSource { onDevice, cloud }
