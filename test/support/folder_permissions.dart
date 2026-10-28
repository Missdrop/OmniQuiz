// Mocks native folder-grant calls so filesystem tests cannot display OS permission dialogs.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests use temporary folders outside the macOS app sandbox. The native
/// bookmark channel belongs to the app runner and is unavailable in flutter test.
/// This does not validate actual security-scoped bookmark access.
void mockFolderPermissions() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('omniquiz/folders');
  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'remember' && call.method != 'restore') {
        throw MissingPluginException(
          'Unexpected folder method: ${call.method}',
        );
      }
      return null;
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
