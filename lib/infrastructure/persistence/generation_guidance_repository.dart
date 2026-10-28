// Persists library-specific samples atomically without retiring saved questions.

import 'dart:convert';

import '../../application/ports/repositories.dart';
import '../../domain/generation_guidance.dart';
import 'database.dart';

/// Uses the library DB, not global provider settings, so subjects remain isolated.
class SqlGenerationGuidanceRepository implements GenerationGuidanceRepository {
  SqlGenerationGuidanceRepository(this.database);
  static const key = 'generation_guidance';
  final QuizDatabase database;

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
    if ((previous == null && value.isEmpty) ||
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
