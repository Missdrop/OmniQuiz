// Bounds authoring preferences and samples; examples must never become answer evidence.

import 'failure.dart';

/// A sample paper is reference data for style, never evidence for an answer.
class ReferenceExample {
  const ReferenceExample({
    required this.id,
    required this.name,
    required this.text,
    this.originalBytes,
  });
  final String id, name, text;

  /// Transient import bytes are written to disk, never into prompts or SQL JSON.
  final List<int>? originalBytes;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'text': text};
  factory ReferenceExample.fromJson(Map<String, dynamic> value) =>
      ReferenceExample(
        id: value['id'] as String,
        name: value['name'] as String,
        text: value['text'] as String,
      );
}

/// Library-specific preferences; bounded snapshots prevent oversized AI requests.
class GenerationGuidance {
  GenerationGuidance({
    this.requirements = '',
    this.pastedExample = '',
    this.questionsPerBatch = 10,
    this.refillThreshold = 10,
    List<ReferenceExample> examples = const [],
  }) : examples = List.unmodifiable(examples) {
    if (questionsPerBatch < 1 ||
        questionsPerBatch > 50 ||
        refillThreshold < 0 ||
        refillThreshold > 100) {
      throw const AppFailure(
        'Invalid generation batch size or refill threshold.',
      );
    }
    if (requirements.length > requirementsLimit ||
        pastedExample.length > pastedLimit ||
        examples.length > exampleCountLimit ||
        totalExampleCharacters > exampleCharactersLimit) {
      throw const AppFailure('Question guidance exceeds its size limits.');
    }
    if (examples.any(
          (e) =>
              e.id.isEmpty ||
              e.id.length > 128 ||
              e.name.isEmpty ||
              e.name.length > 255 ||
              e.text.trim().isEmpty,
        ) ||
        examples.map((e) => e.id).toSet().length != examples.length) {
      throw const AppFailure('Invalid or duplicate reference examples.');
    }
  }
  static const requirementsLimit = 4000;
  static const pastedLimit = 20000;
  static const exampleCountLimit = 8;
  static const exampleCharactersLimit = 120000;
  static const requestCharactersLimit = 12000;
  final String requirements, pastedExample;

  /// A full batch is requested when the unanswered count reaches this threshold.
  final int questionsPerBatch, refillThreshold;
  final List<ReferenceExample> examples;
  int get totalExampleCharacters =>
      pastedExample.length + examples.fold<int>(0, (n, e) => n + e.text.length);
  bool get isEmpty =>
      requirements.trim().isEmpty &&
      pastedExample.trim().isEmpty &&
      examples.isEmpty;
  bool get isDefault =>
      isEmpty && questionsPerBatch == 10 && refillThreshold == 10;

  /// Rotate through long papers across batches; share the budget across all samples.
  List<ReferenceExample> excerpts(int batch) {
    final all = [
      if (pastedExample.trim().isNotEmpty)
        ReferenceExample(
          id: 'pasted',
          name: 'Pasted example',
          text: pastedExample,
        ),
      ...examples,
    ];
    if (all.isEmpty) return const [];
    final budget = requestCharactersLimit ~/ all.length;
    return all
        .map((example) {
          // Code points, rather than UTF-16 offsets, avoid splitting supplementary glyphs.
          final characters = example.text.runes.toList();
          final pages = (characters.length / budget).ceil();
          final offset = (batch % pages) * budget;
          return ReferenceExample(
            id: example.id,
            name: example.name,
            text: String.fromCharCodes(characters.skip(offset).take(budget)),
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'requirements': requirements,
    'pastedExample': pastedExample,
    'questionsPerBatch': questionsPerBatch,
    'refillThreshold': refillThreshold,
    'examples': examples.map((e) => e.toJson()).toList(),
  };
  factory GenerationGuidance.fromJson(Map<String, dynamic> value) =>
      GenerationGuidance(
        requirements: value['requirements'] as String? ?? '',
        pastedExample: value['pastedExample'] as String? ?? '',
        questionsPerBatch: value['questionsPerBatch'] as int? ?? 10,
        refillThreshold: value['refillThreshold'] as int? ?? 10,
        examples: (value['examples'] as List? ?? const [])
            .map(
              (e) => ReferenceExample.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}
