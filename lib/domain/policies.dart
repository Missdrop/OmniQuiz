import 'models.dart';

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

class BufferPolicy {
  const BufferPolicy({this.low = 5, this.target = 20, this.batchSize = 10});
  final int low, target, batchSize;
  int nextBatch(int available, {required bool filling}) {
    if (available >= target || (!filling && available >= low)) return 0;
    return (target - available).clamp(0, batchSize);
  }
}

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now().toUtc();
}

abstract interface class IdGenerator {
  String next();
}
