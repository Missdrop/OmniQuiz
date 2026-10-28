// One practice start supports repeated refills; leaving, backgrounding or ending cannot revive cancelled work.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

Future<void> eventually(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Practice did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  Future<AppDependencies> create(FakeGenerator generator) async {
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: MemoryCredentials(),
      ai: generator,
    );
    addTearDown(deps.dispose);
    await deps.library.import(sample: true);
    await deps.settings.save(
      'https://example.test/v1',
      'test',
      'key',
      false,
      'English',
      false,
    );
    return deps;
  }

  test('one start continuously refills beyond the initial buffer without manual requests', () async {
    final ai = FakeGenerator();
    final deps = await create(ai);
    final vm = deps.practice;
    await vm.startPractice();
    await vm.refresh();
    expect(vm.readyCount, 20);
    for (var i = 0; i < 35; i++) {
      await eventually(() => vm.current != null);
      vm.choose(vm.current!.correctOptionId);
      await vm.submit();
      await vm.next();
    }
    await eventually(() => !deps.coordinator.status.running);
    await vm.refresh();
    expect(ai.calls, greaterThanOrEqualTo(6));
    expect(ai.maxActive, 1);
    expect(vm.active, isTrue);
    expect(vm.readyCount, greaterThan(0));
    await vm.endPractice();
    expect(vm.active, isFalse);
    final calls = ai.calls;
    await vm.next();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(ai.calls, calls);
  });

  test('backgrounding retains the session and resumes refill; ending cancels late work', () async {
    final ai = FakeGenerator()..gate = Completer<void>();
    final deps = await create(ai);
    final vm = deps.practice;
    final initial = vm.startPractice();
    await eventually(() => ai.active == 1);
    await vm.suspendPractice();
    await initial;
    expect(vm.active, isTrue);
    expect(await deps.coordinator.questions.readyCount(null), 0);
    await vm.resumePractice();
    await eventually(() => !deps.coordinator.status.running && ai.calls >= 3);
    expect(await deps.coordinator.questions.readyCount(null), 20);
    await vm.endPractice();
    final calls = ai.calls;
    await vm.resumePractice();
    expect(ai.calls, calls);
    expect(vm.active, isFalse);
  });

  test('ending an in-flight session rejects its provider result', () async {
    final ai = FakeGenerator()..gate = Completer<void>();
    final deps = await create(ai);
    final work = deps.practice.startPractice();
    await eventually(() => ai.active == 1);
    await deps.practice.endPractice();
    await work;
    expect(await deps.coordinator.questions.readyCount(null), 0);
    expect(deps.practice.active, isFalse);
  });

  test('ending immediately after starting cannot restart generation', () async {
    final ai = FakeGenerator();
    final deps = await create(ai);
    final starting = deps.practice.startPractice();
    await deps.practice.endPractice();
    await starting;
    expect(ai.calls, 0);
    expect(deps.practice.active, isFalse);
    expect(deps.coordinator.enabled, isFalse);
  });

  test('ending during a scope change cannot restart practice', () async {
    final ai = FakeGenerator();
    final deps = await create(ai);
    await deps.practice.startPractice();
    final changing = deps.practice.changeScope(deps.library.documents.first.id);
    await deps.practice.endPractice();
    await changing;
    expect(deps.practice.active, isFalse);
    expect(deps.coordinator.enabled, isFalse);
  });
}
