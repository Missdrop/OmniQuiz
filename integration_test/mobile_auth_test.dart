import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_login.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';
import 'package:url_launcher/url_launcher.dart';

import '../test/chatgpt_test.dart' as protocol;

/// Uses synthetic credentials only. Run on Android Emulator or iOS Simulator.
/// The browser and credential store are real OS plugins; OpenAI is never called.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  protocol.main();

  testWidgets('native credential storage survives a new store instance', (
    tester,
  ) async {
    final key = 'omniquiz.integration.${DateTime.now().microsecondsSinceEpoch}';
    final first = PlatformCredentialStore(const FlutterSecureStorage());
    addTearDown(() => first.delete(key));
    await first.write(key, 'synthetic-token');
    final reopened = PlatformCredentialStore(const FlutterSecureStorage());
    expect(await reopened.read(key), 'synthetic-token');
    await reopened.delete(key);
    expect(await first.read(key), isNull);
  });

  testWidgets('system browser redirects to the app loopback listener', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Synthetic sign-in test'))),
    );
    expect(await supportsLaunchMode(LaunchMode.inAppBrowserView), isTrue);
    final page = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => page.close(force: true));
    Uri? callback;
    var browserVisited = false;
    page.listen((request) async {
      browserVisited = true;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '''<!doctype html><html><head>
<meta http-equiv="refresh" content="2;url=${callback.toString().replaceAll('&', '&amp;')}">
</head><body>OmniQuiz synthetic authorization. No account required.</body></html>''',
      );
      await request.response.close();
    });
    final login = ChatGptLogin(
      timeout: const Duration(seconds: 45),
      launch: (authorization) async {
        final params = authorization.queryParameters;
        callback = Uri.parse(params['redirect_uri']!).replace(
          queryParameters: {
            'state': params['state']!,
            'code': 'synthetic-browser-code',
            'client_id': 'oaiapp_integration',
          },
        );
        return launchUrl(
          Uri.parse('http://127.0.0.1:${page.port}/authorize'),
          mode: LaunchMode.inAppBrowserView,
        );
      },
    );
    final result = await login.authorize('urn:uuid:integration-test');
    expect(browserVisited, isTrue);
    expect(result['code'], 'synthetic-browser-code');
    expect(result['client_id'], 'oaiapp_integration');
    expect(result['code_verifier'], isNotEmpty);
  });
}
