// Persists shared UI choices without invalidating generation for purely visual changes.

import '../../application/ports/preferences_repository.dart';
import 'database.dart';

/// SQLite adapter for global UI preferences, independent of paid generation state.
class SqlPreferencesRepository
    implements
        PreferencesRepository,
        AppearancePreferencesRepository,
        QuestionLanguagePreferencesRepository {
  SqlPreferencesRepository(this.database);
  final QuizDatabase database;

  @override
  Future<String?> loadQuestionLanguage() async =>
      (await database
              .customSelect(
                "SELECT value FROM settings WHERE key='question_language'",
              )
              .getSingleOrNull())
          ?.read<String>('value');

  @override
  Future<void> saveQuestionLanguage(String language) =>
      database.customStatement(
        "INSERT OR REPLACE INTO settings VALUES ('question_language', ?)",
        [language],
      );

  @override
  Future<String?> loadThemeMode() async =>
      (await database
              .customSelect(
                "SELECT value FROM settings WHERE key = 'theme_mode'",
              )
              .getSingleOrNull())
          ?.read<String>('value');

  @override
  Future<void> saveThemeMode(String mode) => database.customStatement(
    "INSERT OR REPLACE INTO settings (key, value) VALUES ('theme_mode', ?)",
    [mode],
  );

  @override
  Future<String?> loadInterfaceLanguage() async {
    final row = await database
        .customSelect(
          "SELECT value FROM settings WHERE key = 'interface_language'",
        )
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  @override
  Future<void> saveInterfaceLanguage(String language) =>
      database.customStatement(
        "INSERT OR REPLACE INTO settings (key, value) VALUES ('interface_language', ?)",
        [language],
      );
}
