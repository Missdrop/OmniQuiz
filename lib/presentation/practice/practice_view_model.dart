// Owns the current attempt and practice intent; the coordinator owns bounded background generation.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/generation/coordinator.dart';
import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import '../../domain/policies.dart';

/// Tracks attempts and explicit session intent across refills, review and lifecycle changes.
class PracticeViewModel extends ChangeNotifier {
  void dismissMessage() {
    message = null;
    _notify();
  }

  PracticeViewModel(
    this.questions,
    this.progress,
    this.coordinator,
    this.ids,
    this.clock,
  ) {
    _subscription = coordinator.events.listen((_) {
      unawaited(refresh());
    });
  }
  final QuestionRepository questions;
  final ProgressRepository progress;
  final GenerationCoordinator coordinator;
  final IdGenerator ids;
  final Clock clock;
  late final StreamSubscription<GenerationStatus> _subscription;
  Question? current;
  QuestionRating? rating;
  int _ratingVersion = 0;
  String? selected, scope, message;
  String _attemptId = '';
  bool answered = false, busy = false, reviewing = false;
  int readyCount = 0;
  int _version = 0;
  bool _disposed = false;
  bool _sessionActive = false;
  bool get active => _sessionActive || coordinator.enabled;
  GenerationStatus get generation => coordinator.status;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Refreshes the queue without replacing an answered question still showing its explanation.
  Future<void> refresh() async {
    final version = _version;
    try {
      final ready = await questions.ready(scope);
      if (version != _version || _disposed) return;
      final total = await questions.readyCount(scope);
      if (version != _version || _disposed) return;
      readyCount = total;
      if (message == 'Could not load questions.') message = null;
      if (!busy &&
          !answered &&
          !reviewing &&
          current != null &&
          !ready.any((question) => question.id == current!.id)) {
        current = null;
        selected = null;
      }
      if (current == null && !reviewing && ready.isNotEmpty) {
        _setQuestion(ready.first);
      }
    } catch (_) {
      message = 'Could not load questions.';
    }
    _notify();
  }

  void _setQuestion(Question question) {
    current = question;
    selected = null;
    answered = false;
    _attemptId = ids.next();
    rating = null;
    unawaited(_loadRating(question.id));
  }

  Future<void> _loadRating(String id) async {
    final version = ++_ratingVersion;
    try {
      final stored = await questions.feedback(id);
      if (!_disposed && current?.id == id && version == _ratingVersion) {
        rating = stored;
        _notify();
      }
    } catch (_) {
      /* Quality feedback must not block answering. */
    }
  }

  /// The first tap locks submission synchronously; duplicate taps reuse one attempt.
  Future<void> answer(String option) async {
    if (answered || busy || current == null) return;
    choose(option);
    await submit();
  }

  /// Saves ratings for future batches. Error reports retire the question but keep its history.
  Future<void> rate(QuestionRating value, {String note = ''}) async {
    final question = current;
    if (question == null || busy) return;
    _ratingVersion++;
    busy = true;
    message = null;
    _notify();
    var saved = false;
    try {
      await questions.rate(question.id, value, note: note);
      rating = value;
      saved = true;
    } catch (_) {
      message = 'Could not save question feedback. Please try again.';
    } finally {
      busy = false;
      _notify();
    }
    if (saved && value == QuestionRating.error && !_disposed) await next();
  }

  /// Cancels the old scope first; an explicit end during the await must win over resumption.
  Future<void> changeScope(String? value) async {
    _sessionActive = active;
    _version++;
    scope = value;
    message = null;
    current = null;
    answered = false;
    selected = null;
    reviewing = false;
    await coordinator.quiesce();
    await refresh();
    if (_sessionActive && !_disposed) await startPractice();
  }

  /// Records practice intent once; bounded refills may finish while that intent stays active.
  Future<void> startPractice() async {
    _sessionActive = true;
    message = null;
    _notify();
    await coordinator.start(scope);
  }

  /// Clears intent before cancellation so a later foreground event cannot restart it.
  Future<void> endPractice() async {
    _sessionActive = false;
    await coordinator.stop();
    _notify();
  }

  /// Suspends paid work in the background but remembers an active user's session.
  Future<void> suspendPractice() async {
    _sessionActive = active;
    await coordinator.stop();
  }

  /// Restarts only a previously active, non-review session after foreground return.
  Future<void> resumePractice() async {
    if (_sessionActive && !reviewing && !coordinator.enabled) {
      unawaited(coordinator.start(scope));
    }
  }

  /// Apply new authoring preferences between requests, without reviving an ended session.
  Future<void> applyGuidanceChange(Future<void> Function() persist) async {
    _sessionActive = active;
    await coordinator.quiesce();
    var saved = false;
    try {
      await persist();
      saved = true;
      _version++;
      // Refresh retires the current question only if persistence marked it stale.
      // Keeping the old buffer must also preserve a choice already on screen.
      await refresh();
    } catch (_) {
      _sessionActive = false;
      _notify();
      rethrow;
    } finally {
      // On failure, keep cached questions but do not silently bill another
      // request using the old requirements while the error is still unresolved.
      if (saved && _sessionActive && !_disposed && !reviewing) {
        unawaited(coordinator.start(scope));
      }
    }
  }

  /// Changes only the local choice; persistence happens when the user submits.
  void choose(String value) {
    if (answered || busy) return;
    selected = value;
    _notify();
  }

  /// Uses the same attempt ID across retries to avoid recording an answer twice.
  Future<void> submit() async {
    final q = current;
    final option = selected;
    if (q == null || option == null || answered || busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      await progress.submit(
        AnswerAttempt(
          id: _attemptId,
          questionId: q.id,
          optionId: option,
          correct: q.isCorrect(option),
          at: clock.now(),
        ),
      );
      answered = true;
      unawaited(coordinator.replenish());
      await refresh();
    } catch (e) {
      message = e is AppFailure
          ? e.message
          : 'Could not save your answer. Try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Advances through the appropriate fresh/review queue and requests refill only when active.
  Future<void> next() async {
    if (busy) return;
    _version++;
    current = null;
    selected = null;
    answered = false;
    message = null;
    if (reviewing) {
      final due = (await questions.reviews())
          .where((r) => !r.state.dueAt.isAfter(clock.now()))
          .toList();
      if (due.isNotEmpty) _setQuestion(due.first.question);
    } else {
      await refresh();
      if (active) unawaited(coordinator.replenish());
    }
    _notify();
  }

  /// Review is explicit and must not silently start unrelated paid generation.
  Future<void> review(Question question) async {
    _sessionActive = false;
    await coordinator.stop();
    _version++;
    reviewing = true;
    message = null;
    _setQuestion(question);
    _notify();
  }

  /// Returns to fresh questions without implicitly consenting to a new session.
  Future<void> leaveReview() async {
    reviewing = false;
    await next();
  }

  /// Hides locally; the separate report link lets the user contact the developer.
  Future<void> flag() async {
    final q = current;
    if (q == null || busy) return;
    await questions.flagQuestion(q.id);
    await next();
    unawaited(coordinator.replenish());
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
