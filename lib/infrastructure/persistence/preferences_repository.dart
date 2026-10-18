import '../../application/ports/preferences_repository.dart';
import 'database.dart';

class SqlPreferencesRepository implements PreferencesRepository {
  SqlPreferencesRepository(this.database);
  final QuizDatabase database;

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
