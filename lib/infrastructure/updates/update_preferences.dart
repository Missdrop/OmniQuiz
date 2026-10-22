import 'dart:convert';

import '../persistence/database.dart';

abstract interface class UpdatePreferences {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> value);
}

class SqlUpdatePreferences implements UpdatePreferences {
  SqlUpdatePreferences(this.database);
  final QuizDatabase database;

  @override
  Future<Map<String, dynamic>> load() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='app_updates'")
        .getSingleOrNull();
    return row == null
        ? {}
        : jsonDecode(row.read<String>('value')) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> value) => database.customStatement(
    "INSERT OR REPLACE INTO settings (key,value) VALUES ('app_updates',?)",
    [jsonEncode(value)],
  );
}
