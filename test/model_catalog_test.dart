import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/ai/compatible_model_catalog.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/settings/model_picker.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

void main() {
  test('loads gateway model IDs, retains order, deduplicates, and refuses redirects', () async {
    final catalog = CompatibleModelCatalog(
      clientFactory: () => MockClient((request) async {
        expect(request.url.toString(), 'https://gateway.example/v1/models');
        expect(request.headers['Authorization'], 'Bearer client-key');
        expect(request.followRedirects, false);
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'codex/model'},
              {'id': 'other-model'},
              {'id': 'codex/model'},
              {'id': ''},
            ],
          }),
          200,
        );
      }),
    );
    expect(await catalog.list('https://gateway.example/v1/', 'client-key'), [
      'codex/model',
      'other-model',
    ]);
  });

  test('rejects remote HTTP before sending credentials', () async {
    final catalog = CompatibleModelCatalog(
      clientFactory: () => throw StateError('Must not connect'),
    );
    await expectLater(
      catalog.list('http://192.168.1.10:8317/v1', 'key'),
      throwsA(isA<AppFailure>()),
    );
  });

  for (final status in [302, 401, 403, 404, 429, 500]) {
    test('HTTP $status does not expose gateway error bodies', () async {
      final catalog = CompatibleModelCatalog(
        clientFactory: () =>
            MockClient((_) async => http.Response('private-token', status)),
      );
      await expectLater(
        catalog.list('https://gateway.example/v1', 'key'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('private-token')),
          ),
        ),
      );
    });
  }

  test('bounds catalogs and rejects malformed and empty catalogs', () async {
    for (final body in ['invalid', '{"data":[]}', 'a' * (1024 * 1024 + 1)]) {
      final catalog = CompatibleModelCatalog(
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        catalog.list('https://gateway.example/v1', ''),
        throwsA(isA<AppFailure>()),
      );
    }
  });

  test(
    'model discovery reuses a saved key only for the saved endpoint',
    () async {
      var calls = 0;
      final deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: MemoryCredentials(),
        ai: FakeGenerator(),
        modelCatalog: CompatibleModelCatalog(
          clientFactory: () => MockClient((request) async {
            calls++;
            expect(request.headers['Authorization'], 'Bearer saved-key');
            return http.Response('{"data":[{"id":"model"}]}', 200);
          }),
        ),
      );
      addTearDown(deps.dispose);
      await deps.settings.save(
        'https://gateway.example/v1',
        'model',
        'saved-key',
        false,
        'English',
        false,
      );
      expect(
        await deps.settings.loadModels('https://other.example/v1', '', false),
        isEmpty,
      );
      expect(calls, 0);
      expect(
        await deps.settings.loadModels('https://gateway.example/v1', '', false),
        ['model'],
      );
      expect(calls, 1);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets('model search and selection work at phone width in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selection;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => selection = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      const ModelPicker(models: ['codex/model', 'other-model']),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'CODEX');
      await tester.pump();
      expect(find.text('other-model'), findsNothing);
      await tester.tap(find.text('codex/model'));
      await tester.pumpAndSettle();
      expect(selection, 'codex/model');
      expect(tester.takeException(), isNull);
    });
  }
}
