// Implements revision checks, answer transactions and job leases at the SQLite boundary.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import '../../domain/policies.dart';
import 'codec.dart';
import 'database.dart';

/// Publishes material revisions and retires questions tied to replaced source text.
class SqlMaterialRepository implements MaterialRepository {
  SqlMaterialRepository(this.db);
  final QuizDatabase db;
  StudyDocument _document(QueryRow r) => StudyDocument(
    id: r.read('id'),
    name: r.read('name'),
    revision: r.read('revision'),
    origin: r.read('origin'),
    importedAt: DateTime.fromMillisecondsSinceEpoch(
      r.read('imported_at'),
      isUtc: true,
    ),
    chunkCount: r.read('chunk_count'),
  );
  static const _select =
      '''SELECT d.*, (SELECT COUNT(*) FROM chunks c WHERE c.document_id=d.id) chunk_count FROM documents d''';
  @override
  Future<List<StudyDocument>> documents() async =>
      (await db.customSelect('$_select ORDER BY imported_at DESC').get())
          .map(_document)
          .toList();
  @override
  Future<StudyDocument?> byOrigin(String origin) async {
    final row = await db
        .customSelect(
          '$_select WHERE origin = ?',
          variables: [Variable(origin)],
        )
        .getSingleOrNull();
    return row == null ? null : _document(row);
  }

  @override
  Future<void> importDocument(
    StudyDocument d,
    List<SourceChunk> chunks,
  ) => db.transaction(() async {
    await db.customStatement(
      'UPDATE questions SET stale=1 WHERE document_id=?',
      [d.id],
    );
    await db.customStatement('DELETE FROM chunks WHERE document_id=?', [d.id]);
    await db.customStatement(
      '''INSERT INTO documents VALUES (?,?,?,?,?) ON CONFLICT(id)
      DO UPDATE SET name=excluded.name, revision=excluded.revision, origin=excluded.origin, imported_at=excluded.imported_at''',
      [d.id, d.name, d.revision, d.origin, d.importedAt.millisecondsSinceEpoch],
    );
    for (final c in chunks) {
      await db.customStatement('INSERT INTO chunks VALUES (?,?,?)', [
        c.id,
        d.id,
        jsonEncode(chunkToJson(c)),
      ]);
    }
    await db.invalidateGeneration();
  });
  @override
  Future<void> removeDocument(String id) => db.transaction(() async {
    await db.customStatement(
      'UPDATE questions SET stale=1 WHERE document_id=?',
      [id],
    );
    await db.customStatement('DELETE FROM documents WHERE id=?', [id]);
    await db.invalidateGeneration();
  });
  @override
  Future<List<SourceChunk>> chunks(String? documentId) async {
    final rows = await db
        .customSelect(
          'SELECT payload FROM chunks ${documentId == null ? '' : 'WHERE document_id=?'} ORDER BY rowid',
          variables: [if (documentId != null) Variable(documentId)],
        )
        .get();
    return rows
        .map((r) => chunkFromJson(jsonDecode(r.read('payload'))))
        .toList();
  }

  @override
  Future<List<SourceChunk>> generationChunks(
    String? documentId,
    int cursor,
    int limit,
  ) async {
    if (limit <= 0) return [];
    final where = documentId == null ? '' : 'WHERE document_id=?';
    final variables = [if (documentId != null) Variable(documentId)];
    final total =
        (await db
                .customSelect(
                  'SELECT COUNT(*) n FROM chunks $where',
                  variables: variables,
                )
                .getSingle())
            .read<int>('n');
    if (total == 0) return [];
    final start = cursor % total;
    final count = limit.clamp(0, total);
    final first = await db
        .customSelect(
          'SELECT payload FROM chunks $where ORDER BY rowid LIMIT ? OFFSET ?',
          variables: [...variables, Variable(count), Variable(start)],
        )
        .get();
    final remaining = count - first.length;
    final wrapped = remaining == 0
        ? <QueryRow>[]
        : await db
              .customSelect(
                'SELECT payload FROM chunks $where ORDER BY rowid LIMIT ?',
                variables: [...variables, Variable(remaining)],
              )
              .get();
    return [
      ...first,
      ...wrapped,
    ].map((r) => chunkFromJson(jsonDecode(r.read('payload')))).toList();
  }
}

/// Queries ready/review queues while excluding stale and explicitly hidden questions.
class SqlQuestionRepository implements QuestionRepository {
  SqlQuestionRepository(this.db);
  final QuizDatabase db;
  Question _question(QueryRow r) => questionFromJson(
    jsonDecode(r.read('payload')),
    flagged: r.read<int>('flagged') == 1,
    stale: r.read<int>('stale') == 1,
  );
  @override
  Future<List<Question>> ready(String? scope) async =>
      (await db
              .customSelect(
                '''SELECT q.* FROM questions q
    WHERE stale=0 AND flagged=0 AND NOT EXISTS (SELECT 1 FROM attempts a WHERE a.question_id=q.id)
    ${scope == null ? '' : 'AND document_id=?'} ORDER BY created_at, id LIMIT 40''',
                variables: [if (scope != null) Variable(scope)],
              )
              .get())
          .map(_question)
          .toList();
  @override
  Future<int> readyCount(String? scope) async =>
      (await db
              .customSelect(
                """SELECT COUNT(*) n FROM questions q WHERE stale=0 AND flagged=0
    AND NOT EXISTS (SELECT 1 FROM attempts a WHERE a.question_id=q.id)
    ${scope == null ? '' : 'AND document_id=?'}""",
                variables: [if (scope != null) Variable(scope)],
              )
              .getSingle())
          .read<int>('n');

  @override
  Future<List<String>> recentPrompts(String? scope) async =>
      (await db
              .customSelect(
                '''SELECT payload FROM questions
    WHERE stale=0 ${scope == null ? '' : 'AND document_id=?'} ORDER BY created_at DESC LIMIT 200''',
                variables: [if (scope != null) Variable(scope)],
              )
              .get())
          .map((r) => jsonDecode(r.read<String>('payload'))['prompt'] as String)
          .toList();
  @override
  Future<List<ReviewEntry>> reviews() async =>
      (await db.customSelect('''SELECT q.*, r.streak, r.mistakes, r.due_at
    FROM reviews r JOIN questions q ON q.id=r.question_id WHERE r.streak<3 AND q.flagged=0 AND q.stale=0
    ORDER BY r.due_at''').get())
          .map(
            (r) => ReviewEntry(
              _question(r),
              ReviewState(
                questionId: r.read('id'),
                streak: r.read('streak'),
                mistakes: r.read('mistakes'),
                dueAt: DateTime.fromMillisecondsSinceEpoch(
                  r.read('due_at'),
                  isUtc: true,
                ),
              ),
            ),
          )
          .toList();
  @override
  Future<void> flagQuestion(String id) =>
      db.customStatement('UPDATE questions SET flagged=1 WHERE id=?', [id]);
  @override
  Future<QuestionRating?> feedback(String id) async {
    final row = await db
        .customSelect(
          'SELECT rating FROM feedback WHERE question_id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : QuestionRating.values.byName(row.read<String>('rating'));
  }

  @override
  Future<List<QuestionFeedback>> generationFeedback(String? scope) async {
    final rows = await db
        .customSelect(
          '''SELECT q.payload, f.rating, f.note FROM feedback f
      JOIN questions q ON q.id=f.question_id JOIN documents d ON d.id=q.document_id
      WHERE q.revision=d.revision ${scope == null ? '' : 'AND q.document_id=?'}
      ORDER BY f.at DESC, f.rowid DESC LIMIT 6''',
          variables: [if (scope != null) Variable(scope)],
        )
        .get();
    String clip(String text, int max) =>
        String.fromCharCodes(text.runes.take(max));
    final result = <QuestionFeedback>[];
    var budget = 6000;
    for (final row in rows) {
      final question = questionFromJson(
        jsonDecode(row.read<String>('payload')),
      );
      final feedback = QuestionFeedback(
        rating: QuestionRating.values.byName(row.read<String>('rating')),
        prompt: clip(question.prompt, 500),
        options: [
          for (final option in question.options)
            clip('${option.id}: ${option.text}', 100),
        ],
        explanation: clip(question.explanation, 400),
        note: clip(row.read<String>('note'), 1000),
      );
      final size = jsonEncode(feedback.toJson()).length;
      if (size > budget) break;
      result.add(feedback);
      budget -= size;
    }
    return result;
  }

  @override
  Future<void> rate(String id, QuestionRating rating, {String note = ''}) =>
      db.transaction(() async {
        if (note.length > 1000) {
          throw const AppFailure('Feedback must not exceed 1000 characters.');
        }
        await db.customStatement(
          'INSERT OR REPLACE INTO feedback (question_id,rating,note,at) VALUES (?,?,?,?)',
          [
            id,
            rating.name,
            note,
            DateTime.now().toUtc().millisecondsSinceEpoch,
          ],
        );
        if (rating == QuestionRating.error) await flagQuestion(id);
      });
  @override
  Future<StudyStats> stats() async {
    final r = await db.customSelect(
      '''SELECT
      (SELECT COUNT(*) FROM documents) documents,
      (SELECT COUNT(*) FROM questions q WHERE stale=0 AND flagged=0 AND NOT EXISTS (SELECT 1 FROM attempts a WHERE a.question_id=q.id)) ready,
      (SELECT COUNT(*) FROM attempts) attempts,
      (SELECT COUNT(*) FROM attempts WHERE correct=1) correct,
      (SELECT COUNT(*) FROM reviews r JOIN questions q ON q.id=r.question_id WHERE streak<3 AND stale=0 AND flagged=0) review''',
    ).getSingle();
    return StudyStats(
      documents: r.read('documents'),
      ready: r.read('ready'),
      attempts: r.read('attempts'),
      correct: r.read('correct'),
      review: r.read('review'),
    );
  }
}

/// Commits an attempt once and advances its review schedule in the same transaction.
class SqlProgressRepository implements ProgressRepository {
  SqlProgressRepository(this.db, this.policy);
  final QuizDatabase db;
  final ReviewPolicy policy;
  @override
  Future<void> submit(AnswerAttempt a) => db.transaction(() async {
    // A stable attempt ID makes a UI retry idempotent. This check must precede
    // reading and advancing the schedule, or a double tap could count twice.
    if (await db
            .customSelect(
              'SELECT id FROM attempts WHERE id=?',
              variables: [Variable(a.id)],
            )
            .getSingleOrNull() !=
        null) {
      return;
    }
    final row = await db
        .customSelect(
          'SELECT payload, stale, flagged FROM questions WHERE id=?',
          variables: [Variable(a.questionId)],
        )
        .getSingleOrNull();
    if (row == null ||
        row.read<int>('stale') == 1 ||
        row.read<int>('flagged') == 1) {
      throw const AppFailure(
        'This question is no longer available. Choose another question.',
      );
    }
    final q = questionFromJson(jsonDecode(row.read('payload')));
    if (!q.options.any((o) => o.id == a.optionId) ||
        q.isCorrect(a.optionId) != a.correct) {
      throw const AppFailure('Invalid answer submission.');
    }
    final r = await db
        .customSelect(
          'SELECT * FROM reviews WHERE question_id=?',
          variables: [Variable(a.questionId)],
        )
        .getSingleOrNull();
    final previous = r == null
        ? null
        : ReviewState(
            questionId: a.questionId,
            streak: r.read('streak'),
            mistakes: r.read('mistakes'),
            dueAt: DateTime.fromMillisecondsSinceEpoch(
              r.read('due_at'),
              isUtc: true,
            ),
          );
    final next = policy.afterAnswer(a, previous);
    await db.customStatement('INSERT INTO attempts VALUES (?,?,?,?,?)', [
      a.id,
      a.questionId,
      a.optionId,
      a.correct ? 1 : 0,
      a.at.millisecondsSinceEpoch,
    ]);
    if (next != null) {
      await db.customStatement(
        'INSERT OR REPLACE INTO reviews VALUES (?,?,?,?)',
        [
          next.questionId,
          next.streak,
          next.mistakes,
          next.dueAt.millisecondsSinceEpoch,
        ],
      );
    }
  });
}

/// Serializes non-secret profiles and invalidates incompatible queued work.
class SqlProfileRepository implements ProfileRepository {
  SqlProfileRepository(this.db);
  final QuizDatabase db;
  @override
  Future<ProviderProfile?> load() async {
    final r = await db
        .customSelect("SELECT value FROM settings WHERE key='profile'")
        .getSingleOrNull();
    return r == null ? null : profileFromJson(jsonDecode(r.read('value')));
  }

  @override
  Future<void> save(ProviderProfile p) => db.transaction(() async {
    await db.customStatement(
      "INSERT OR REPLACE INTO settings VALUES ('profile', ?)",
      [jsonEncode(profileToJson(p))],
    );
    await db.invalidateGeneration();
  });
}

/// Enforces current epochs and leases before accepting generated questions.
class SqlJobRepository implements JobRepository {
  SqlJobRepository(this.db, this.clock);
  final QuizDatabase db;
  final Clock clock;
  @override
  Future<int> epoch() async => int.parse(
    (await db
            .customSelect("SELECT value FROM settings WHERE key='epoch'")
            .getSingle())
        .read('value'),
  );
  @override
  Future<void> recover() async {
    // Requests are not replayed automatically after restart: remote billing may
    // have happened before a crash. The next user-started session refills safely.
    await db.customStatement(
      "UPDATE jobs SET state='cancelled', request='{}', message='Interrupted; start practice to refill.' WHERE state IN ('queued','running','retryScheduled')",
    );
  }

  @override
  Future<void> enqueue(GenerationJob j) => db.customStatement(
    '''INSERT INTO jobs
    (id,epoch,scope,request,state) VALUES (?,?,?,?,'queued')''',
    [
      j.id,
      j.epoch,
      j.scope,
      jsonEncode({
        'profile': profileToJson(j.request.profile),
        'chunks': j.request.chunks.map(chunkToJson).toList(),
        'count': j.request.count,
        'recentPrompts': j.request.recentPrompts,
        'additionalRequirements': j.request.additionalRequirements,
        'qualityFeedback': j.request.qualityFeedback
            .map((item) => item.toJson())
            .toList(),
        'referenceExamples': j.request.referenceExamples
            .map((e) => e.toJson())
            .toList(),
      }),
    ],
  );
  @override
  Future<bool> claim(String id, DateTime now) => db.transaction(() async {
    final changed = await db.customUpdate(
      """UPDATE jobs SET state='running', attempt=attempt+1, lease_until=?
      WHERE id=? AND (state='queued' OR (state='retryScheduled' AND retry_at<=?))
      AND epoch=(SELECT CAST(value AS INTEGER) FROM settings WHERE key='epoch')""",
      variables: [
        Variable(now.add(const Duration(minutes: 5)).millisecondsSinceEpoch),
        Variable(id),
        Variable(now.millisecondsSinceEpoch),
      ],
    );
    return changed == 1;
  });
  @override
  Future<bool> complete(
    GenerationJob j,
    List<Question> questions,
  ) => db.transaction(() async {
    final row = await db
        .customSelect(
          'SELECT state FROM jobs WHERE id=?',
          variables: [Variable(j.id)],
        )
        .getSingle();
    if (row.read<String>('state') == 'completed') return true;
    if (row.read<String>('state') != 'running' || j.epoch != await epoch()) {
      return false;
    }
    var inserted = 0;
    for (final q in questions) {
      final current = await db
          .customSelect(
            'SELECT revision FROM documents WHERE id=?',
            variables: [Variable(q.source.documentId)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('revision') != q.source.revision) {
        continue;
      }
      inserted += await db.customUpdate(
        '''INSERT OR IGNORE INTO questions
        (id,document_id,revision,payload,fingerprint,created_at) VALUES (?,?,?,?,?,?)''',
        variables: [
          Variable(q.id),
          Variable(q.source.documentId),
          Variable(q.source.revision),
          Variable(jsonEncode(questionToJson(q))),
          Variable(q.prompt.toLowerCase().replaceAll(RegExp(r'\s+'), '')),
          Variable(clock.now().millisecondsSinceEpoch),
        ],
      );
    }
    if (inserted == 0) {
      throw const AppFailure(
        'No new valid questions were generated. Try another source or model.',
      );
    }
    await db.customStatement(
      "UPDATE jobs SET state='completed', request='{}' WHERE id=?",
      [j.id],
    );
    return true;
  });
  @override
  Future<void> fail(String id, String message, {bool cancelled = false}) =>
      db.customStatement(
        "UPDATE jobs SET state=?, message=?, request='{}' WHERE id=? AND state IN ('queued','running','retryScheduled')",
        [cancelled ? 'cancelled' : 'failed', message, id],
      );
  @override
  Future<void> retry(String id, DateTime at) => db.customStatement(
    "UPDATE jobs SET state='retryScheduled', retry_at=? WHERE id=? AND state='running'",
    [at.millisecondsSinceEpoch, id],
  );
}
