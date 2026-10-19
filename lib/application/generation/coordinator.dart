import 'dart:async';
import 'dart:math';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../ports/repositories.dart';

class GenerationStatus {
  const GenerationStatus(
    this.message, {
    this.running = false,
    this.error = false,
  });
  final String message;
  final bool running, error;
}

/// Owns at most one generation loop; no widgets, SQL or provider DTOs here.
class GenerationCoordinator {
  GenerationCoordinator({
    required this.materials,
    required this.questions,
    required this.profiles,
    required this.jobs,
    required this.generator,
    required this.ids,
    required this.clock,
    this.policy = const BufferPolicy(),
  });
  final MaterialRepository materials;
  final QuestionRepository questions;
  final ProfileRepository profiles;
  final JobRepository jobs;
  final AiQuestionGenerator generator;
  final IdGenerator ids;
  final Clock clock;
  final BufferPolicy policy;
  final _events = StreamController<GenerationStatus>.broadcast();
  Stream<GenerationStatus> get events => _events.stream;
  GenerationStatus status = const GenerationStatus('Ready when you are');
  bool _enabled = false, _disposed = false;
  int _token = 0, _cursor = 0;
  String? _scope;
  Future<void>? _loop;
  GenerationJob? _job;
  Timer? _retryTimer;
  Completer<void>? _retryWait;
  bool get enabled => _enabled;
  void _emit(String message, {bool running = false, bool error = false}) {
    if (_disposed) return;
    status = GenerationStatus(message, running: running, error: error);
    _events.add(status);
  }

  Future<void> start(String? scope) async {
    await stop();
    _enabled = true;
    _scope = scope;
    _cursor = Random().nextInt(10000);
    await replenish();
  }

  Future<void> stop() async {
    _enabled = false;
    _token++;
    _retryTimer?.cancel();
    if (_retryWait != null && !_retryWait!.isCompleted) _retryWait!.complete();
    generator.cancel();
    final job = _job;
    if (job != null) {
      await jobs.fail(
        job.id,
        'Paused by user or app lifecycle.',
        cancelled: true,
      );
    }
    _emit('Generation paused · cached questions remain available');
  }

  /// Waits for any cancelled request to leave its loop before maintenance.
  Future<void> quiesce() async {
    await stop();
    await _loop;
  }

  Future<void> replenish() async {
    if (!_enabled || _disposed) return;
    final previous = _loop;
    if (previous != null) {
      await previous;
      if (!_enabled || _disposed) return;
      // Another consumer may have started a loop while this caller waited.
      if (_loop != null) return;
    }
    final token = _token;
    final work = _fill(token);
    _loop = work;
    try {
      await work;
    } finally {
      if (identical(_loop, work)) _loop = null;
    }
  }

  bool _current(int token) => !_disposed && _enabled && token == _token;
  Future<void> _fill(int token) async {
    var filling = false;
    try {
      while (_current(token)) {
        final available = await questions.readyCount(_scope);
        final count = policy.nextBatch(available, filling: filling);
        if (count == 0) {
          _emit('$available questions ready');
          return;
        }
        final job = await _prepareJob(count);
        if (!_current(token)) return;
        _job = job;
        await jobs.enqueue(job);
        final complete = await _executeJob(job, token);
        if (!_current(token)) return;
        _job = null;
        if (!complete) return;
        filling = true;
        _emit('New questions saved', running: true);
      }
    } catch (e) {
      if (!_current(token)) return;
      final message = e is AppFailure
          ? e.message
          : 'Could not save or generate questions. Please try again.';
      final job = _job;
      if (job != null) await jobs.fail(job.id, message);
      _job = null;
      _enabled = false;
      _emit(message, error: true);
    }
  }

  Future<GenerationJob> _prepareJob(int count) async {
    final profile = await profiles.load();
    if (profile == null) {
      throw const AppFailure('Configure your AI provider in Settings first.');
    }
    final selected = await materials.generationChunks(_scope, _cursor, 3);
    if (selected.isEmpty) {
      throw const AppFailure('Import study materials first.');
    }
    _cursor += selected.length;
    return GenerationJob(
      id: ids.next(),
      epoch: await jobs.epoch(),
      scope: _scope,
      request: GenerationRequest(
        profile: profile,
        chunks: selected,
        count: count,
        recentPrompts: await questions.recentPrompts(_scope),
      ),
    );
  }

  Future<bool> _executeJob(GenerationJob job, int token) async {
    for (var attempt = 0; attempt < 3 && _current(token); attempt++) {
      if (!await jobs.claim(job.id, clock.now())) return false;
      _emit(
        attempt == 0
            ? 'Preparing your next questions…'
            : 'Retrying generation (${attempt + 1}/3)…',
        running: true,
      );
      try {
        final generated = await generator.generate(job.request);
        if (!_current(token)) return false;
        final complete = await jobs.complete(job, generated);
        if (!complete) {
          _enabled = false;
          _emit('Materials or settings changed. Start generation again.');
        }
        return complete;
      } on AppFailure catch (error) {
        if (!_current(token)) return false;
        if (!error.retryable || attempt == 2) rethrow;
        final delay = error.retryAfter ?? Duration(seconds: 2 << attempt);
        // Long provider waits require a user restart, without blocking a switch.
        if (delay > const Duration(minutes: 2)) rethrow;
        await jobs.retry(job.id, clock.now().add(delay));
        if (!_current(token)) return false;
        await _waitBeforeRetry(delay);
      }
    }
    return false;
  }

  Future<void> _waitBeforeRetry(Duration delay) async {
    final wait = Completer<void>();
    _retryWait = wait;
    _retryTimer = Timer(delay, wait.complete);
    await wait.future;
    _retryTimer = null;
    _retryWait = null;
  }

  Future<void> dispose() async {
    await stop();
    await _loop;
    _disposed = true;
    await _events.close();
  }
}
