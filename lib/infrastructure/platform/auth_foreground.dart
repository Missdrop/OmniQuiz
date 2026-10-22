import 'dart:async';

import 'package:flutter/widgets.dart';

/// Android may suspend the caller's network while a Custom Tab is foreground.
/// Wait before consuming a single-use authorization code, never retry it blindly.
Future<void> waitForAuthForeground({
  Future<void>? cancelled,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final binding = WidgetsBinding.instance;
  if (binding.lifecycleState == null ||
      binding.lifecycleState == AppLifecycleState.resumed) {
    return;
  }
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await Future.any<void>([
      resumed.future,
      if (cancelled != null)
        cancelled.then((_) => throw StateError('Authorization cancelled')),
    ]).timeout(timeout);
  } finally {
    listener.dispose();
  }
}
