import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models.dart';
import '../platform/auth_foreground.dart';

class ChatGptLogin {
  ChatGptLogin({
    Future<bool> Function(Uri)? launch,
    this.timeout = const Duration(minutes: 5),
  }) : launch = launch ?? _launch;
  final Future<bool> Function(Uri) launch;
  final Duration timeout;
  Completer<Map<String, String>>? _pending;
  Completer<void>? _cancelSignal;
  static Future<bool> _launch(Uri uri) async {
    final mobile = Platform.isAndroid || Platform.isIOS;
    if (mobile && !await supportsLaunchMode(LaunchMode.inAppBrowserView)) {
      return false;
    }
    return launchUrl(
      uri,
      mode: mobile
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication,
    );
  }

  static String random() => base64Url
      .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  void cancel() {
    if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
      _cancelSignal!.complete();
    }
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete({'error': 'cancelled'});
    }
  }

  Future<Map<String, String>> authorize(String host, {String? clientId}) async {
    if (_pending != null) {
      throw const AppFailure('ChatGPT sign-in is already running.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pending = _pending = Completer<Map<String, String>>();
    final cancelSignal = _cancelSignal = Completer<void>();
    final state = random(), nonce = random(), verifier = random();
    final redirect = 'http://127.0.0.1:${server.port}/auth/callback';
    final uri = Uri.https('auth.openai.com', '/api/accounts/authorize', {
      'client_id': clientId ?? 'dynamic_agent_client',
      if (clientId == null) 'agent_name_hint': 'OmniQuiz',
      'ext_agent_host_id': host,
      'response_type': 'code',
      'redirect_uri': redirect,
      'scope': 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
      'resource': 'https://api.openai.com/v1',
      'state': state,
      'nonce': nonce,
      'code_challenge_method': 'S256',
      'code_challenge': base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', ''),
    });
    server.listen((request) async {
      final query = request.uri.queryParameters;
      final valid =
          request.method == 'GET' &&
          request.uri.path == '/auth/callback' &&
          request.headers.value('host') == '127.0.0.1:${server.port}' &&
          query['state'] == state &&
          !pending.isCompleted &&
          request.uri.queryParametersAll.values.every(
            (values) => values.length == 1,
          );
      request.response.statusCode = valid ? 200 : 400;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.contentType = ContentType.text;
      request.response.write(
        valid
            ? 'Return to OmniQuiz to finish signing in. / 请返回 OmniQuiz 完成登录。'
            : 'Invalid callback.',
      );
      await request.response.close();
      if (valid && !pending.isCompleted) pending.complete(query);
    });
    try {
      if (!await launch(uri)) throw const FormatException();
      final result = await pending.future.timeout(timeout);
      final issued = result['client_id'] ?? clientId;
      if (result['error'] != null ||
          result['code'] == null ||
          issued == null ||
          !issued.startsWith('oaiapp_') ||
          (clientId != null && issued != clientId)) {
        throw const FormatException();
      }
      if (Platform.isAndroid) {
        await waitForAuthForeground(
          cancelled: cancelSignal.future,
          timeout: timeout,
        );
      }
      return {
        'client_id': issued,
        'code': result['code']!,
        'code_verifier': verifier,
        'redirect_uri': redirect,
        'nonce': nonce,
      };
    } catch (_) {
      throw const AppFailure(
        'ChatGPT sign-in was cancelled or expired. Please try again.',
      );
    } finally {
      _pending = null;
      _cancelSignal = null;
      await server.close(force: true);
      if (Platform.isIOS) {
        try {
          await closeInAppWebView();
        } catch (_) {}
      }
    }
  }
}
