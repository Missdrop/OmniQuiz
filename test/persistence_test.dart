// SQL transactions enforce idempotent answers, current revisions and leased job completion.

import 'dart:convert';

import 'package:omniquiz/infrastructure/persistence/codec.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/policies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';

const chunk = SourceChunk(
  id: 'c',
  documentId: 'd',
  documentName: 'Notes',
  revision: 'r',
  location: 'Section 1',
  text: 'Water freezes at zero degrees Celsius.',
);
Question sampleQuestion() => Question(
  id: 'q',
  prompt: 'At what temperature does water freeze?',
  options: [
    const AnswerOption('a', '0°C'),
    const AnswerOption('b', '10°C'),
    const AnswerOption('c', '20°C'),
    const AnswerOption('d', '30°C'),
  ],
  correctOptionId: 'a',
  explanation: 'The notes specify zero.',
  topic: 'Water',
  source: chunk,
  quote: 'Water freezes at zero degrees Celsius.',
);

void main() {
  late QuizDatabase db;
  late SqlMaterialRepository materials;
  late SqlJobRepository jobs;
  late SqlQuestionRepository questions;
  setUp(() async {
    db = QuizDatabase(NativeDatabase.memory());
    materials = SqlMaterialRepository(db);
    jobs = SqlJobRepository(db, SystemClock());
    questions = SqlQuestionRepository(db);
    await materials.importDocument(
      StudyDocument(
        id: 'd',
        name: 'Notes',
        revision: 'r',
        origin: 'notes',
        importedAt: DateTime.utc(2026),
        chunkCount: 1,
      ),
      [chunk],
    );
  });
  tearDown(() => db.close());
  Future<GenerationJob> prepare() async {
    final job = GenerationJob(
      id: 'job',
      epoch: await jobs.epoch(),
      scope: null,
      request: GenerationRequest(
        profile: ProviderProfile(
          baseUrl: 'https://example.com/v1',
          model: 'test',
        ),
        chunks: [chunk],
        count: 1,
        recentPrompts: [],
      ),
    );
    await jobs.enqueue(job);
    expect(await jobs.claim(job.id, DateTime.now().toUtc()), true);
    expect(await jobs.claim(job.id, DateTime.now().toUtc()), false);
    return job;
  }

  test('publishing and recording attempts are idempotent', () async {
    final job = await prepare();
    await jobs.complete(job, [sampleQuestion()]);
    await jobs.complete(job, [sampleQuestion()]);
    expect((await questions.ready(null)).length, 1);
    final progress = SqlProgressRepository(db, const ReviewPolicy());
    final attempt = AnswerAttempt(
      id: 'attempt',
      questionId: 'q',
      optionId: 'b',
      correct: false,
      at: DateTime.utc(2026),
    );
    await progress.submit(attempt);
    await progress.submit(attempt);
    expect((await questions.stats()).attempts, 1);
    expect(await questions.ready(null), isEmpty);
    expect((await questions.reviews()).single.state.mistakes, 1);
  });
  test('deleting a source prevents late jobs from publishing', () async {
    final job = await prepare();
    await materials.removeDocument('d');
    expect(await jobs.complete(job, [sampleQuestion()]), false);
    expect(await questions.ready(null), isEmpty);
  });
  test(
    'restart cancels unfinished jobs without replaying paid requests',
    () async {
      final job = await prepare();
      await jobs.recover();
      expect(await jobs.complete(job, [sampleQuestion()]), false);
    },
  );
  test('generation windows wrap in source order and ignore unrelated malformed payloads', () async {
    for (var n = 0; n < 8; n++) {
      await db.customStatement('INSERT INTO chunks VALUES (?,?,?)', [
        'extra-$n',
        'd',
        n == 0
            ? '{bad-json'
            : jsonEncode(
                chunkToJson(
                  SourceChunk(
                    id: 'extra-$n',
                    documentId: 'd',
                    documentName: 'Notes',
                    revision: 'r',
                    location: '$n',
                    text: 'Text $n',
                  ),
                ),
              ),
      ]);
    }
    // The corrupted row outside this window must never be read or decoded.
    final selected = await materials.generationChunks('d', 7, 3);
    expect(selected.map((c) => c.id), ['extra-6', 'extra-7', 'c']);
    expect(await materials.generationChunks('missing', 0, 3), isEmpty);
  });
  test(
    'ready count is independent of the 40-question display window',
    () async {
      final job = await prepare();
      final base = sampleQuestion();
      await jobs.complete(
        job,
        List.generate(
          55,
          (n) => Question(
            id: 'q-$n',
            prompt: 'Question $n?',
            options: base.options,
            correctOptionId: base.correctOptionId,
            explanation: base.explanation,
            topic: base.topic,
            source: base.source,
            quote: base.quote,
          ),
        ),
      );
      expect(await questions.ready(null), hasLength(40));
      expect(await questions.readyCount(null), 55);
    },
  );
}
