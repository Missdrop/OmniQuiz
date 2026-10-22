import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/application/generation/coordinator.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/policies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';

import 'persistence_test.dart' show chunk;

class FakeGenerator implements AiQuestionGenerator {
  int calls = 0, active = 0, maxActive = 0;
  Completer<void>? gate;
  AppFailure? failure;
  @override
  Future<List<Question>> generate(GenerationRequest request) async {
    calls++;
    if (failure != null) throw failure!;
    active++;
    if (active > maxActive) maxActive = active;
    await gate?.future;
    active--;
    return List.generate(
      request.count,
      (i) => Question(
        id: '$calls-$i',
        prompt: 'Question $calls-$i?',
        options: [
          const AnswerOption('a', 'A'),
          const AnswerOption('b', 'B'),
          const AnswerOption('c', 'C'),
          const AnswerOption('d', 'D'),
        ],
        correctOptionId: 'a',
        explanation: 'Because A.',
        topic: 'Topic',
        source: request.chunks.first,
        quote: request.chunks.first.text,
      ),
    );
  }

  @override
  void cancel() {
    if (active > 0 && gate != null && !gate!.isCompleted) gate!.complete();
  }

  @override
  Future<void> probe(ProviderProfile profile, String apiKey) async {}
}

void main() {
  late QuizDatabase db;
  late SqlQuestionRepository questions;
  late GenerationCoordinator coordinator;
  late FakeGenerator ai;
  setUp(() async {
    db = QuizDatabase(NativeDatabase.memory());
    final materials = SqlMaterialRepository(db);
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
    final profiles = SqlProfileRepository(db);
    await profiles.save(
      ProviderProfile(baseUrl: 'https://example.com/v1', model: 'test'),
    );
    questions = SqlQuestionRepository(db);
    ai = FakeGenerator();
    coordinator = GenerationCoordinator(
      materials: materials,
      questions: questions,
      profiles: profiles,
      jobs: SqlJobRepository(db, SystemClock()),
      generator: ai,
      ids: const UuidGenerator(),
      clock: SystemClock(),
    );
  });
  tearDown(() async {
    await coordinator.dispose();
    await db.close();
  });
  test(
    'concurrent refill triggers share a bounded single-request loop',
    () async {
      final work = coordinator.start(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Future.wait([
        work,
        coordinator.replenish(),
        coordinator.replenish(),
      ]);
      expect((await questions.ready(null)).length, 20);
      expect(ai.calls, 2);
      expect(ai.maxActive, 1);
    },
  );
  test('pausing rejects a late provider result', () async {
    ai.gate = Completer<void>();
    final work = coordinator.start(null);
    while (ai.calls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await coordinator.stop();
    await work;
    expect(await questions.ready(null), isEmpty);
    expect(coordinator.enabled, false);
  });
  test('stopping cancels a provider retry wait immediately', () async {
    ai.failure = const AppFailure(
      'rate limited',
      retryable: true,
      retryAfter: Duration(seconds: 90),
    );
    final work = coordinator.start(null);
    while (ai.calls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Let the failed request enter its scheduled retry state.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await coordinator.quiesce().timeout(const Duration(seconds: 1));
    await work;
    expect(ai.calls, 1);
    expect(coordinator.enabled, false);
  });
}
