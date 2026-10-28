// Shared widget/native flow for two connection types and independent draft editing.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/app.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/presentation/settings/connection_editor.dart';
import 'package:omniquiz/presentation/settings/connection_manager.dart';
import 'package:omniquiz/presentation/settings/settings_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

Future<void> connectionFlow(WidgetTester tester, {bool native = false}) async {
  late AppDependencies deps;
  final generator = FakeGenerator();
  await tester.runAsync(() async {
    deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: MemoryCredentials(),
      ai: generator,
    );
    await deps.language.select('en');
    await deps.settings.saveApiConnection(
      name: 'Official',
      url: 'https://api.openai.com/v1',
      model: 'first-model',
      key: 'first-private-key',
    );
    await deps.library.import(sample: true);
    await deps.practice.startPractice();
    await deps.practice.refresh();
    deps.practice.choose('b');
    await deps.practice.endPractice();
  });
  Future<void> settle() async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle();
  }

  final capture = GlobalKey();
  try {
    final first = deps.settings.connections.activeId;
    final question = deps.practice.current!.id;
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: OmniQuizApp(dependencies: deps),
      ),
    );
    await settle();
    await tap(find.byIcon(Icons.tune_rounded));
    expect(find.widgetWithText(TextField, 'API key'), findsNothing);
    await tap(find.text('Configure AI'));
    await tap(find.text('Add connection'));
    final types = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ListTile),
    );
    expect(types, findsNWidgets(2));
    await tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('OpenAI-compatible API'),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Connection name'),
      'Local CLIProxyAPI',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API base URL'),
      'http://127.0.0.1:8317/v1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Model ID'),
      'second-model',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'second-private-key',
    );
    await tap(find.text('Save connection'));
    for (
      var i = 0;
      i < 40 && find.byType(ConnectionEditor).evaluate().isNotEmpty;
      i++
    ) {
      await settle();
    }
    expect(deps.settings.connections.items, hasLength(2));
    expect(deps.settings.connections.activeId, first);
    final second = deps.settings.connections.items.last;
    Finder card() => find.byKey(ValueKey('connection-${second.id}'));
    await tap(find.descendant(of: card(), matching: find.text('Use')));
    for (var i = 0; i < 30 && deps.settings.busy; i++) {
      await settle();
    }
    expect(deps.settings.connections.activeId, second.id);
    expect(
      await tester.runAsync(() => deps.practice.questions.readyCount(null)),
      20,
    );
    expect(deps.practice.current!.id, question);
    expect(deps.practice.selected, 'b');
    expect(
      generator.calls,
      4,
      reason: 'Saving or switching inactive practice does not issue inference',
    );
    await tap(find.descendant(of: card(), matching: find.text('Edit')));
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'API key'))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Model ID'),
      'unsaved-draft',
    );
    await tester.runAsync(() => deps.language.select('zh'));
    await settle();
    expect(find.text('unsaved-draft'), findsOneWidget);
    expect(deps.settings.profile!.model, 'second-model');
    if (!native || Platform.isWindows) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      if (native) await tester.binding.setSurfaceSize(const Size(390, 844));
    }
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    await settle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (native && Platform.isWindows) {
      final image =
          await (capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('.tooling/connections-editor-phone.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
    await tap(find.byType(BackButton).first);
    expect(find.byType(ConnectionManager), findsOneWidget);
    expect(deps.settings.profile!.model, 'second-model');
    if (native && const bool.fromEnvironment('UI_AUDIT_PAUSE')) {
      debugPrint('CONNECTION_UI_READY');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 10)),
      );
    }
    // After removing the current connection, adding another must still offer
    // an explicit Save-and-use action alongside saving it as an inactive draft.
    await tester.runAsync(() => deps.settings.deleteConnection(second.id));
    await settle();
    await tap(find.text('添加连接'));
    await tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('OpenAI 兼容 API'),
      ),
    );
    expect(find.text('保存连接'), findsOneWidget);
    expect(find.text('保存并使用'), findsOneWidget);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(deps.dispose);
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    if (!native || Platform.isWindows) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
    if (native && Platform.isWindows) await tester.binding.setSurfaceSize(null);
  }
}

void main() {
  testWidgets(
    'connection management keeps independent settings and fits narrow layouts',
    connectionFlow,
  );
}
