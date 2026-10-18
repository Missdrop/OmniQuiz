import 'package:drift/drift.dart';

/// SQL is confined to persistence adapters. Schema changes require a migration.
class QuizDatabase extends GeneratedDatabase {
  QuizDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final statement in _schema) {
        await customStatement(statement);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static const _schema = [
    'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    "INSERT INTO settings VALUES ('epoch', '0')",
    '''CREATE TABLE documents (id TEXT PRIMARY KEY, name TEXT NOT NULL,
       revision TEXT NOT NULL, origin TEXT NOT NULL UNIQUE, imported_at INTEGER NOT NULL)''',
    '''CREATE TABLE chunks (id TEXT PRIMARY KEY, document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
       payload TEXT NOT NULL)''',
    '''CREATE TABLE questions (id TEXT PRIMARY KEY, document_id TEXT NOT NULL,
       revision TEXT NOT NULL, payload TEXT NOT NULL, fingerprint TEXT NOT NULL,
       created_at INTEGER NOT NULL, flagged INTEGER NOT NULL DEFAULT 0,
       stale INTEGER NOT NULL DEFAULT 0, UNIQUE(document_id, revision, fingerprint))''',
    '''CREATE TABLE attempts (id TEXT PRIMARY KEY, question_id TEXT NOT NULL REFERENCES questions(id),
       option_id TEXT NOT NULL, correct INTEGER NOT NULL, at INTEGER NOT NULL)''',
    '''CREATE TABLE reviews (question_id TEXT PRIMARY KEY REFERENCES questions(id),
       streak INTEGER NOT NULL, mistakes INTEGER NOT NULL, due_at INTEGER NOT NULL)''',
    '''CREATE TABLE jobs (id TEXT PRIMARY KEY, epoch INTEGER NOT NULL, scope TEXT,
       request TEXT NOT NULL, state TEXT NOT NULL, attempt INTEGER NOT NULL DEFAULT 0,
       lease_until INTEGER, retry_at INTEGER, message TEXT)''',
    'CREATE INDEX question_scope ON questions(document_id, stale, flagged)',
    'CREATE INDEX attempt_question ON attempts(question_id)',
    'CREATE INDEX review_due ON reviews(due_at)',
  ];

  Future<void> invalidateGeneration() async {
    await customStatement(
      "UPDATE settings SET value = CAST(value AS INTEGER) + 1 WHERE key = 'epoch'",
    );
    await customStatement(
      "UPDATE jobs SET state = 'cancelled' WHERE state IN ('queued', 'running', 'retryScheduled')",
    );
  }
}
