// Android uses a system-browser sheet so the OAuth caller remains visible and runnable.
import 'package:flutter/services.dart';

class AndroidAuthBrowser {
  static const _channel = MethodChannel(
    'io.github.missdrop.omniquiz/auth_browser',
  );
  static Future<bool> open(Uri uri) async =>
      await _channel.invokeMethod<bool>('open', {'url': uri.toString()}) ??
      false;
  static Future<void> close() => _channel.invokeMethod<void>('close');

  /// Listen only for the lifetime of the active attempt; a browser dismisses without a URL.
  static void onClosed(void Function()? callback) {
    _channel.setMethodCallHandler(
      callback == null
          ? null
          : (call) async {
              if (call.method == 'closed') callback();
            },
    );
  }
}
