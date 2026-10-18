import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/generation/coordinator.dart';
import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import '../../domain/policies.dart';

class PracticeViewModel extends ChangeNotifier {
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
  String? selected, scope, message;
  String _attemptId = '';
  bool answered = false, busy = false, reviewing = false;
  int readyCount = 0;
  int _version = 0;
  bool _disposed = false;
  GenerationStatus get generation => coordinator.status;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final version = _version;
    try {
      final ready = await questions.ready(scope);
      if (version != _version || _disposed) return;
      readyCount = ready.length;
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
  }

  Future<void> changeScope(String? value) async {
    _version++;
    scope = value;
    current = null;
    answered = false;
    selected = null;
    reviewing = false;
    await coordinator.stop();
    await refresh();
  }

  Future<void> startGeneration() async {
    message = null;
    unawaited(coordinator.start(scope));
    _notify();
  }

  Future<void> stopGeneration() => coordinator.stop();
  void choose(String value) {
    if (answered || busy) return;
    selected = value;
    _notify();
  }

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
    }
    _notify();
  }

  Future<void> review(Question question) async {
    await coordinator.stop();
    _version++;
    reviewing = true;
    message = null;
    _setQuestion(question);
    _notify();
  }

  Future<void> leaveReview() async {
    reviewing = false;
    await next();
  }

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
