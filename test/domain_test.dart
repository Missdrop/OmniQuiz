import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/policies.dart';

void main() {
  test('review needs three correct answers after a mistake', () {
    const policy = ReviewPolicy();
    final now = DateTime.utc(2026);
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
    }
    expect(state!.mistakes, 1);
  });
  test('buffer respects its target and low watermark', () {
    const policy = BufferPolicy();
    expect(policy.nextBatch(6, filling: false), 0);
    expect(policy.nextBatch(4, filling: false), 10);
    expect(policy.nextBatch(14, filling: true), 6);
    expect(policy.nextBatch(20, filling: true), 0);
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
