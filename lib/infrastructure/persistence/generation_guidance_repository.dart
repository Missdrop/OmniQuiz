// Persists library-specific samples atomically without retiring saved questions.

import 'dart:convert';

import '../../application/ports/repositories.dart';
import '../../domain/generation_guidance.dart';
import '../../domain/policies.dart';
import 'database.dart';

/// Uses the library DB, not global provider settings, so subjects remain isolated.
class SqlGenerationGuidanceRepository
    implements GenerationGuidanceRepository, GenerationBufferRepository {
  SqlGenerationGuidanceRepository(this.database);
  static const key = 'generation_guidance';
  final QuizDatabase database;

  @override
  Future<BufferPolicy> loadBufferPolicy() async {
    final settings = await load();
    return BufferPolicy(
      low: settings.refillThreshold,
      batchSize: settings.questionsPerBatch,
    );
  }

  @override
  Future<GenerationGuidance> load() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='$key'")
        .getSingleOrNull();
    return row == null
        ? GenerationGuidance()
        : GenerationGuidance.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row.read<String>('value')) as Map,
            ),
          );
  }

  @override
  Future<void> save(GenerationGuidance value) => database.transaction(() async {
    final encoded = jsonEncode(value.toJson());
    final previous = await database
        .customSelect("SELECT value FROM settings WHERE key='$key'")
        .getSingleOrNull();
    if ((previous == null && value.isDefault) ||
        previous?.read<String>('value') == encoded) {
      return;
    }
    await database.customStatement(
      'INSERT OR REPLACE INTO settings (key,value) VALUES (?,?)',
      [key, encoded],
    );
    await database.invalidateGeneration();
  });
}
