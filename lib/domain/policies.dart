// Pure scheduling and buffer rules; clocks and identifiers are injectable for deterministic tests.

import 'models.dart';

/// Pure review scheduling; early correct answers must not advance due-time mastery.
class ReviewPolicy {
  const ReviewPolicy();
  ReviewState? afterAnswer(AnswerAttempt attempt, ReviewState? previous) {
    if (previous == null && attempt.correct) return null;
    // Early practice is recorded, but must not advance spaced-review mastery.
    if (attempt.correct &&
        previous != null &&
        attempt.at.isBefore(previous.dueAt)) {
      return previous;
    }
    final streak = attempt.correct ? (previous?.streak ?? 0) + 1 : 0;
    final delay = !attempt.correct
        ? const Duration(minutes: 10)
        : Duration(
            days: switch (streak) {
              1 => 1,
              2 => 3,
              _ => 0,
            },
          );
    return ReviewState(
      questionId: attempt.questionId,
      streak: streak,
      mistakes: (previous?.mistakes ?? 0) + (attempt.correct ? 0 : 1),
      dueAt: attempt.at.add(delay),
    );
  }
}

/// Requests full batches only at or below the unanswered-question threshold.
class BufferPolicy {
  const BufferPolicy({this.low = 10, this.batchSize = 10});
  final int low, batchSize;
  int nextBatch(int available) => available <= low ? batchSize : 0;
}

/// Supplies time independently of wall-clock APIs for deterministic scheduling.
abstract interface class Clock {
  DateTime now();
}

/// Production clock using UTC instants for persisted scheduling.
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Produces opaque identities without coupling use cases to a UUID implementation.
abstract interface class IdGenerator {
  String next();
}
