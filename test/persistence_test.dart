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
}
