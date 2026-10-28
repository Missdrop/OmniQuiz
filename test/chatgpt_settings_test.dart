// Account/model activation and presentation independently from optional connection probing.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/app/theme.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_sessions.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/presentation/settings/settings_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;

class Sessions extends ChatGptSessions {
  Sessions(super.storage);
  List<String> available = ['first-model', 'second-model'];
  bool saved = false;
  @override
  Future<String> signIn({String? clientId}) async {
    saved = true;
    return 'oaiapp_test';
  }

  @override
  Future<Map<String, String>> accounts() async =>
      saved ? {'oaiapp_test': 'student@example.test'} : {};
  @override
  Future<List<String>> models(String id) async => available;
}

class Generator extends FakeGenerator {
  int probes = 0;
  @override
  Future<void> probe(ProviderProfile profile, String apiKey) async {
    probes++;
  }
}

void main() {
  test('login saves first model without probing; model changes persist and refresh preserves them', () async {
    final db = QuizDatabase(NativeDatabase.memory());
    final credentials = MemoryCredentials(), ai = Generator();
    final deps = await AppDependencies.create(
      database: db,
      credentialStore: credentials,
      ai: ai,
    );
    final sessions = Sessions(credentials);
    final vm = SettingsViewModel(
      deps.settings.profiles,
      credentials,
      deps.settings.configure,
      ai,
      deps.coordinator,
      chatGpt: sessions,
    );
    addTearDown(() async {
      vm.dispose();
      await deps.dispose();
      await db.close();
    });
    await vm.load();
    await vm.signInChatGpt();
    expect(sessions.saved, isTrue);
    expect((await vm.profiles.load())!.model, 'first-model');
    expect(vm.profile!.chatGpt, isTrue);
    expect(ai.probes, 0);
    await vm.useChatGpt('second-model', 'English', test: false);
    await vm.selectChatGpt('oaiapp_test');
    expect((await vm.profiles.load())!.model, 'second-model');
    expect(vm.profile!.language, 'English');
    await vm.load();
    expect(vm.chatGptAccount, 'oaiapp_test');
    await vm.useChatGpt('second-model', 'English');
    expect(ai.probes, 1);
    await vm.signInChatGpt();
    expect(vm.profile!.model, 'first-model');
    expect(vm.profile!.language, 'English');
  });

  test('missing models keep the account and previous active profile with a retry message', () async {
    final db = QuizDatabase(NativeDatabase.memory());
    final credentials = MemoryCredentials(), ai = Generator();
    final deps = await AppDependencies.create(
      database: db,
      credentialStore: credentials,
      ai: ai,
    );
    final sessions = Sessions(credentials)..available = [];
    final vm = SettingsViewModel(
      deps.settings.profiles,
      credentials,
      deps.settings.configure,
      ai,
      deps.coordinator,
      chatGpt: sessions,
    );
    addTearDown(() async {
      vm.dispose();
      await deps.dispose();
      await db.close();
    });
    await vm.profiles.save(
      ProviderProfile(
        baseUrl: 'https://provider.example/v1',
        model: 'previous-model',
      ),
    );
    await vm.load();
    await vm.signInChatGpt();
    expect(vm.chatGptAccounts, contains('oaiapp_test'));
    expect((await vm.profiles.load())!.model, 'previous-model');
    expect(vm.message, contains('Account saved.'));
    sessions.available = ['first-model'];
    await vm.selectChatGpt('oaiapp_test');
    expect((await vm.profiles.load())!.model, 'first-model');
  });

  test('account labels contain no registration ID or subject', () async {
    final credentials = MemoryCredentials();
    await credentials.write(
      'omniquiz.chatgpt.accounts.v1',
      jsonEncode({
        'oaiapp_private_registration': {
          'email': 'student@example.test',
          'sub': 'private-subject',
          'verified': true,
        },
        'oaiapp_other': {'sub': 'private-subject', 'verified': true},
      }),
    );
    expect((await ChatGptSessions(credentials).accounts()).values, [
      'student@example.test',
      'ChatGPT account',
    ]);
  });

  test('Windows body, title and button typography use the same CJK family', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final theme = buildTheme();
    for (final style in [
      theme.textTheme.bodySmall,
      theme.textTheme.bodyMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.labelLarge,
      theme.inputDecorationTheme.helperStyle,
    ]) {
      expect(style!.fontFamily, appFontFamily);
    }
  });
}
