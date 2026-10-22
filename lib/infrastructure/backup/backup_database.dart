import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:path/path.dart' as p;

import '../persistence/database.dart';
import '../persistence/scan_state_store.dart';
import '../../application/libraries/scan_state.dart';

/// SQLite snapshot hygiene and validation are independent of ZIP/file picking.
class BackupDatabase {
  // Required columns are shared by schema versions 1 and 2 (v2 adds an index).
  // Checking table names alone accepts snapshots that repositories cannot read.
  static const _tables = {
    'settings': 'key, value',
    'documents': 'id, name, revision, origin, imported_at',
    'chunks': 'id, document_id, payload',
    'questions': 'id, document_id, revision, payload, fingerprint, created_at, flagged, stale',
    'attempts': 'id, question_id, option_id, correct, at',
    'reviews': 'question_id, streak, mistakes, due_at',
    'jobs': 'id, epoch, scope, request, state, attempt, lease_until, retry_at, message',
  };

  static Future<void> snapshot(QuizDatabase database, String target) async {
    await database.customStatement('VACUUM INTO ?', [target]);
    await Isolate.run(() => _sanitize(target));
  }

  static void _sanitize(String target) {
    final copy = sqlite.sqlite3.open(target);
    try {
      copy.execute(
        "DELETE FROM settings WHERE key NOT IN ('epoch', 'library_scan')",
      );
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
      final scan = db.select(
        "SELECT value FROM settings WHERE key='library_scan'",
      );
      if (scan.isNotEmpty) {
        SqlScanStateStore.decode(scan.single['value'] as String);
      }
      if (db
          .select(
            "SELECT key FROM settings WHERE key NOT IN ('epoch', 'library_scan')",
          )
          .isNotEmpty) {
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
          _tables.containsKey(row['name']) &&
          !(row['sql'] as String).toUpperCase().contains('VIRTUAL TABLE')) {
        found.add(row['name'] as String);
      } else if (row['type'] != 'index') {
        throw const FormatException('Unexpected schema object');
      }
    }
    if (!found.containsAll(_tables.keys)) {
      throw const FormatException('Missing backup tables');
    }
    for (final table in _tables.entries) {
      db.select('SELECT ${table.value} FROM ${table.key} LIMIT 0');
    }
  }

  static void rebaseOrigins(
    String path,
    String libraryId,
    Map<String, String> origins,
    String materialDirectory,
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
      final scan = db.select(
        "SELECT value FROM settings WHERE key='library_scan'",
      );
      if (scan.isNotEmpty) {
        final records = SqlScanStateStore.decode(
          scan.single['value'] as String,
        );
        // Restored files have new paths/timestamps. Preserve exclusions, but
        // discard scan hints so the independent copy verifies content afresh.
        final rebased = _rebaseExclusions(records, origins, materialDirectory);
        db.execute("UPDATE settings SET value=? WHERE key='library_scan'", [
          SqlScanStateStore.encode(rebased),
        ]);
      }
      db.execute('COMMIT');
    } finally {
      db.close();
    }
  }

  static Map<String, ScanRecord> _rebaseExclusions(
    Map<String, ScanRecord> records,
    Map<String, String> origins,
    String root,
  ) {
    final rebased = <String, ScanRecord>{};
    for (final entry in records.entries) {
      if (!entry.value.ignored) continue;
      final name = entry.value.name.replaceAll('\\', '/');
      if (p.posix.isAbsolute(name) ||
          p.windows.isAbsolute(name) ||
          name
              .split('/')
              .any(
                (part) =>
                    part.isEmpty ||
                    part == '.' ||
                    part == '..' ||
                    RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(part),
              )) {
        throw const FormatException('Invalid excluded source path');
      }
      // A missing excluded file has no archived material mapping. Its relative
      // path still has to stay excluded if the user later adds that file again.
      final target =
          origins[entry.key] ?? p.join(root, p.joinAll(name.split('/')));
      rebased[target] = ScanRecord(
        name: p.relative(target, from: root).replaceAll('\\', '/'),
        ignored: true,
      );
    }
    return rebased;
  }
}
