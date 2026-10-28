// Notifications expire or dismiss without changing saved connections or hiding a required repair.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/application/generation/coordinator.dart';
import 'package:omniquiz/application/ports/connection_repository.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/application/use_cases/configure_provider.dart';
import 'package:omniquiz/domain/ai_connection.dart';
import 'package:omniquiz/domain/generation_guidance.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_sessions.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/practice/guidance_view_model.dart';
import 'package:omniquiz/presentation/settings/settings_view_model.dart';
import 'package:omniquiz/presentation/shared/widgets.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

class _Profiles extends Fake implements ProfileRepository {
  @override
  Future<ProviderProfile?> load() async => null;
}

class _Connections extends Fake implements ConnectionRepository {
  final value = AiConnections();
  @override
  Future<AiConnections> load() async => value;
}

class _Configure extends Fake implements ConfigureProvider {}

class _Coordinator extends Fake implements GenerationCoordinator {}

class _Access extends Fake implements DocumentAccess {}

class _Parser extends Fake implements DocumentParser {}

class _Login extends ChatGptSessions {
  _Login() : super(MemoryCredentials());
  Completer<String>? pending;
  @override
  Future<String> signIn({String? clientId}) =>
      (pending = Completer<String>()).future;
  void expire() => pending!.completeError(
    const AppFailure(
      'ChatGPT sign-in was cancelled or expired. Please try again.',
    ),
  );
  @override
  void cancelLogin() {
    if (pending != null && !pending!.isCompleted) expire();
  }

  @override
  Future<Map<String, String>> accounts() async => {};
}

class _RepairGuidance extends Fake implements GenerationGuidanceRepository {
  int writes = 0;
  @override
  Future<GenerationGuidance> load() async =>
      throw StateError('Corrupt settings');
  @override
  Future<void> save(GenerationGuidance value) async {
    writes++;
  }
}

void main() {
  testWidgets(
    'login cancellation and expiry clear on close, retry, successful reload and timeout',
    (tester) async {
      final sessions = _Login(), connections = _Connections();
      final vm = SettingsViewModel(
        _Profiles(),
        MemoryCredentials(),
        _Configure(),
        FakeGenerator(),
        _Coordinator(),
        chatGpt: sessions,
        connectionRepository: connections,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: vm,
              builder: (_, _) => vm.message == null
                  ? const SizedBox()
                  : Notice(
                      vm.message!,
                      error: vm.actionFailed,
                      onDismiss: vm.dismissMessage,
                    ),
            ),
          ),
        ),
      );
      Future<void> begin() async {
        unawaited(vm.connectSubscription(name: 'ChatGPT'));
        await tester.pump();
        expect(vm.signingIn, isTrue);
        expect(
          vm.message,
          isNull,
          reason: 'Starting a retry clears the old warning immediately',
        );
      }

      await begin();
      vm.cancelSignIn();
      await tester.pumpAndSettle();
      expect(vm.actionFailed, isFalse);
      expect(find.text('ChatGPT sign-in cancelled.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(vm.message, isNull);

      await begin();
      sessions.expire();
      await tester.pumpAndSettle();
      expect(vm.actionFailed, isTrue);
      await tester.pump(const Duration(seconds: 11));
      expect(vm.message, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      expect(vm.message, isNull);

      await begin();
      sessions.expire();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(vm.message, isNull);
      expect(vm.actionFailed, isFalse);

      await begin();
      sessions.expire();
      await tester.pumpAndSettle();
      await begin();
      vm.cancelSignIn();
      await tester.pumpAndSettle();
      await vm.load();
      await tester.pump();
      expect(vm.message, isNull);
      expect(
        connections.value.items,
        isEmpty,
        reason: 'Dismissing a warning never creates or selects a connection',
      );
      await vm.activateConnection('missing');
      await tester.pump();
      expect(vm.actionFailed, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(
        vm.message,
        isNotNull,
        reason:
            'Actionable configuration errors remain until dismissed or retried',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(vm.message, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('dismissing a guidance load error still allows the same default draft to repair storage', () async {
    final repository = _RepairGuidance();
    final vm = GuidanceViewModel(
      repository,
      _Access(),
      _Parser(),
      (persist) => persist(),
    );
    try {
      await vm.load();
      expect(vm.error, isNotNull);
      vm.dismissError();
      expect(vm.error, isNull);
      expect(await vm.save(GenerationGuidance()), isTrue);
      expect(repository.writes, 1);
    } finally {
      vm.dispose();
    }
  });
}
