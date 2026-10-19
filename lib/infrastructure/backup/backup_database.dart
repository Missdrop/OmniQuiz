import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../persistence/database.dart';

/// SQLite snapshot hygiene and validation are independent of ZIP/file picking.
class BackupDatabase {
  static const _tables = {
    'settings',
    'documents',
    'chunks',
    'questions',
    'attempts',
    'reviews',
    'jobs',
  };

  static Future<void> snapshot(QuizDatabase database, String target) async {
    await database.customStatement('VACUUM INTO ?', [target]);
    await Isolate.run(() => _sanitize(target));
  }

  static void _sanitize(String target) {
    final copy = sqlite.sqlite3.open(target);
    try {
      copy.execute("DELETE FROM settings WHERE key != 'epoch'");
      copy.execute(
        "UPDATE jobs SET state='cancelled', request='{}' WHERE state!='completed'",
      );
      // Remove deleted profile/catalog bytes from freelist pages as well.
      copy.execute('VACUUM');
    } finally {
      copy.close();
    }
  }

  static void validate(String path) {
    final db = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    try {
      final version =
          db.select('PRAGMA user_version').single.values.single as int;
      if (version < 1 ||
          version > QuizDatabase.currentSchemaVersion ||
          db.select('PRAGMA quick_check').single.values.single != 'ok' ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const FormatException('Invalid backup database');
      }
      _validateSchema(db);
      if (db.select("SELECT key FROM settings WHERE key!='epoch'").isNotEmpty) {
        throw const FormatException('Unexpected settings in backup');
      }
    } finally {
      db.close();
    }
  }

  static void _validateSchema(sqlite.Database db) {
    final found = <String>{};
    for (final row in db.select(
      "SELECT name,type,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
    )) {
      if (row['type'] == 'table' &&
          _tables.contains(row['name']) &&
          !(row['sql'] as String).toUpperCase().contains('VIRTUAL TABLE')) {
        found.add(row['name'] as String);
      } else if (row['type'] != 'index') {
        throw const FormatException('Unexpected schema object');
      }
    }
    if (!found.containsAll(_tables)) {
      throw const FormatException('Missing backup tables');
    }
  }

  static void rebaseOrigins(
    String path,
    String libraryId,
    Map<String, String> origins,
  ) {
    final db = sqlite.sqlite3.open(path);
    try {
      db.execute('BEGIN IMMEDIATE');
      for (final document in db.select('SELECT id, origin FROM documents')) {
        // Missing originals keep their extracted text and learning history.
        final origin =
            origins[document['origin']] ??
            'restored:$libraryId:${document['id']}';
        db.execute('UPDATE documents SET origin=? WHERE id=?', [
          origin,
          document['id'],
        ]);
      }
      db.execute('COMMIT');
    } finally {
      db.close();
    }
  }
}
