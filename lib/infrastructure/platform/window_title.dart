// Synchronizes the native Windows caption because MaterialApp titles alone do not update HWNDs.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows does not apply MaterialApp's title to the native window caption.
class DesktopWindowTitle {
  static const channel = MethodChannel('omniquiz/window');

  static Future<void> update(String title) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      await channel.invokeMethod<void>('setTitle', title);
    } on MissingPluginException {
      // Widget tests do not run the native window host.
    } on PlatformException catch (error) {
      debugPrint('Could not update window title: ${error.code}');
    }
  }
}
