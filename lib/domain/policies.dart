import 'models.dart';

class ReviewPolicy {
  const ReviewPolicy();
  ReviewState? afterAnswer(AnswerAttempt attempt, ReviewState? previous) {
    if (previous == null && attempt.correct) return null;
    final streak = attempt.correct ? (previous?.streak ?? 0) + 1 : 0;
    final delay = !attempt.correct
        ? const Duration(minutes: 10)
        : Duration(
            days: switch (streak) {
              1 => 1,
              2 => 3,
              _ => 7,
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
