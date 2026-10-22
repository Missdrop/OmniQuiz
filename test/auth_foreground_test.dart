import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/infrastructure/platform/auth_foreground.dart';

void main() {
  testWidgets('authorization waits for resume before token exchange', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    var continued = false;
    final ready = waitForAuthForeground().then((_) => continued = true);
    await tester.pump();
    expect(continued, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(continued, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await ready;
    expect(continued, isTrue);
  });

  testWidgets('cancel and timeout release the foreground listener', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    final cancelled = Completer<void>();
    final cancellation = expectLater(
      waitForAuthForeground(cancelled: cancelled.future),
      throwsStateError,
    );
    cancelled.complete();
    await cancellation;
    final expiration = expectLater(
      waitForAuthForeground(timeout: const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 2));
    await expiration;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitForAuthForeground();
    expect(tester.takeException(), isNull);
  });
}
