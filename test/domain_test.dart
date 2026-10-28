// Pure question invariants and review scheduling without platform or persistence dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/policies.dart';

void main() {
  test('review needs three correct answers after a mistake', () {
    const policy = ReviewPolicy();
    var now = DateTime.utc(2026);
    ReviewState? state;
    for (var n = 0; n < 4; n++) {
      state = policy.afterAnswer(
        AnswerAttempt(
          id: '$n',
          questionId: 'q',
          optionId: 'a',
          correct: n > 0,
          at: now,
        ),
        state,
      );
      expect(state!.mastered, n == 3);
      now = state.dueAt;
    }
    expect(state!.mistakes, 1);
  });
  test(
    'early correct practice preserves due date and streak; mistakes reset them',
    () {
      const policy = ReviewPolicy();
      final previous = ReviewState(
        questionId: 'q',
        streak: 2,
        mistakes: 1,
        dueAt: DateTime.utc(2026, 1, 3),
      );
      AnswerAttempt attempt(bool correct, DateTime at) => AnswerAttempt(
        id: 'a',
        questionId: 'q',
        optionId: 'a',
        correct: correct,
        at: at,
      );
      expect(
        policy.afterAnswer(attempt(true, DateTime.utc(2026, 1, 2)), previous),
        same(previous),
      );
      final failed = policy.afterAnswer(
        attempt(false, DateTime.utc(2026, 1, 2)),
        previous,
      )!;
      expect(failed.streak, 0);
      expect(failed.mistakes, 2);
      expect(
        policy.afterAnswer(attempt(true, previous.dueAt), previous)!.mastered,
        true,
      );
    },
  );
  test('buffer refills at the threshold with a complete configured batch', () {
    const policy = BufferPolicy();
    expect(policy.nextBatch(11), 0);
    expect(policy.nextBatch(10), 10);
    expect(policy.nextBatch(9), 10);
    expect(policy.nextBatch(0), 10);
    expect(const BufferPolicy(low: 0, batchSize: 3).nextBatch(1), 0);
    expect(const BufferPolicy(low: 0, batchSize: 3).nextBatch(0), 3);
  });
  test('profile rejects insecure remote URLs and embedded credentials', () {
    for (final url in [
      'http://example.com/v1',
      'https://user:key@example.com',
      'file:///tmp/a',
    ]) {
      expect(
        () => ProviderProfile(baseUrl: url, model: 'model'),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      ProviderProfile(
        baseUrl: 'http://localhost:8080/v1/',
        model: 'm',
      ).completionsUri.toString(),
      'http://localhost:8080/v1/chat/completions',
    );
  });
}
