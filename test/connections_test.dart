// Named connection persistence, credential isolation and explicit switching with real SQLite.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/domain/ai_connection.dart';
import 'package:omniquiz/infrastructure/persistence/connection_repository.dart';
import 'package:omniquiz/infrastructure/persistence/selected_connection_profile.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/backup/backup_database.dart';
import 'package:omniquiz/presentation/settings/settings_view_model.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'coordinator_test.dart' show FakeGenerator;
import 'chatgpt_settings_test.dart' show Sessions, Generator;

class RejectingConnectionStore extends SqlConnectionRepository {
  RejectingConnectionStore(super.database);
  bool reject = false;
  @override
  Future<AiConnections> save(AiConnection connection, {bool activate = false}) {
    if (reject) throw StateError('Simulated storage failure');
    return super.save(connection, activate: activate);
  }
}

void main() {
  test('failed credential rotation retains the old connection and removes the uncommitted secret', () async {
    final keys = MemoryCredentials(), ai = FakeGenerator();
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: keys,
      ai: ai,
    );
    final store = RejectingConnectionStore(deps.database);
    final vm = SettingsViewModel(
      deps.settings.profiles,
      keys,
      deps.settings.configure,
      ai,
      deps.coordinator,
      connectionRepository: store,
      applyConnectionChange: deps.practice.applyGuidanceChange,
    );
    try {
      final original = (await vm.saveApiConnection(
        name: 'Stable',
        url: 'https://api.openai.com/v1',
        model: 'stable',
        key: 'old-secret',
      ))!;
      store.reject = true;
      expect(
        await vm.saveApiConnection(
          id: original.id,
          name: original.name,
          url: original.profile.baseUrl,
          model: 'new',
          key: 'new-secret',
        ),
        isNull,
      );
      expect(keys.values, {original.profile.credentialRef: 'old-secret'});
      expect((await deps.settings.profiles.load())!.model, 'stable');
      await SqlProfileRepository(
        deps.database,
      ).save(ProviderProfile(baseUrl: 'https://stale.test/v1', model: 'stale'));
      expect(
        (await SelectedConnectionProfile(store).load())!.model,
        'stable',
        reason: 'Generation must resolve the explicit active connection, never the legacy mirror',
      );
    } finally {
      vm.dispose();
      await deps.dispose();
    }
  });
  test('migrates a legacy profile once; selection and names persist without exporting secrets', () async {
    final db = QuizDatabase(NativeDatabase.memory());
    final profiles = SqlProfileRepository(db);
    await profiles.save(
      ProviderProfile(
        baseUrl: 'https://old.test/v1',
        model: 'old',
        credentialRef: 'opaque',
      ),
    );
    final repository = SqlConnectionRepository(db);
    final initial = await repository.load();
    expect(initial.items, hasLength(1));
    expect(initial.active!.profile.credentialRef, 'opaque');
    final other = AiConnection(
      id: 'second',
      name: 'CLIProxyAPI',
      profile: ProviderProfile(
        baseUrl: 'http://127.0.0.1:8317/v1',
        model: 'other',
        credentialRef: 'second-key',
      ),
    );
    await repository.save(other);
    expect((await profiles.load())!.model, 'old');
    await repository.activate('second');
    expect((await profiles.load())!.model, 'other');
    expect((await SqlConnectionRepository(db).load()).activeId, 'second');
    final directory = await Directory.systemTemp.createTemp(
      'omniquiz-connection-backup-',
    );
    final path = '${directory.path}/copy.sqlite';
    await BackupDatabase.snapshot(db, path);
    final copy = QuizDatabase(NativeDatabase(File(path)));
    expect(
      await copy
          .customSelect(
            "SELECT value FROM settings WHERE key IN ('profile','ai_connections')",
          )
          .get(),
      isEmpty,
    );
    await copy.close();
    await db.close();
    await directory.delete(recursive: true);
  });

  test('inactive saves and tests keep practice alive; explicit switches preserve every cached question', () async {
    final credentials = MemoryCredentials();
    final ai = FakeGenerator();
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: credentials,
      ai: ai,
    );
    try {
      final vm = deps.settings;
      await vm.load();
      final first = (await vm.saveApiConnection(
        name: 'Official',
        url: 'https://api.openai.com/v1',
        model: 'first-model',
        key: 'first-secret',
      ))!;
      final second = (await vm.saveApiConnection(
        name: 'Gateway',
        url: 'http://127.0.0.1:8317/v1',
        model: 'second-model',
        key: 'second-secret',
      ))!;
      expect(vm.connections.activeId, first.id);
      expect(
        await credentials.read(first.profile.credentialRef),
        'first-secret',
      );
      await deps.library.import(sample: true);
      await deps.practice.startPractice();
      await deps.practice.refresh();
      deps.practice.choose('b');
      final original = deps.practice.current!.id;
      final ready = await deps.practice.questions.readyCount(null);
      final token = deps.coordinator.status;
      expect(
        await vm.probeApiConnection(
          id: second.id,
          url: second.profile.baseUrl,
          model: 'second-model',
          key: '',
          noKey: false,
          jsonMode: false,
        ),
        isTrue,
      );
      expect(deps.coordinator.enabled, isTrue);
      expect(identical(deps.coordinator.status, token), isTrue);
      final edited = await vm.saveApiConnection(
        id: second.id,
        name: 'Local proxy',
        url: second.profile.baseUrl,
        model: 'third-model',
        key: '',
      );
      expect(edited!.profile.credentialRef, second.profile.credentialRef);
      expect(deps.coordinator.enabled, isTrue);
      expect(vm.connections.activeId, first.id);
      expect(await vm.activateConnection(second.id), isTrue);
      expect(deps.practice.current!.id, original);
      expect(deps.practice.selected, 'b');
      expect(await deps.practice.questions.readyCount(null), ready);
      expect(deps.practice.active, isTrue);
      await vm.deleteConnection(second.id);
      expect(vm.connections.active, isNull);
      expect(deps.practice.active, isFalse);
      expect(vm.connections.items.single.id, first.id);
      expect(
        await credentials.read(first.profile.credentialRef),
        'first-secret',
      );
      expect(await credentials.read(second.profile.credentialRef), isNull);
      expect(await deps.practice.questions.readyCount(null), ready);
    } finally {
      await deps.dispose();
    }
  });

  test(
    'a draft cannot borrow another connection key and tests cannot activate it',
    () async {
      final keys = MemoryCredentials();
      final deps = await AppDependencies.create(
        database: QuizDatabase(NativeDatabase.memory()),
        credentialStore: keys,
        ai: FakeGenerator(),
      );
      try {
        final vm = deps.settings;
        final first = (await vm.saveApiConnection(
          name: 'First',
          url: 'https://one.test/v1',
          model: 'm',
          key: 'private',
        ))!;
        expect(
          await vm.saveApiConnection(
            name: 'Second',
            url: 'https://one.test/v1',
            model: 'm',
            key: '',
          ),
          isNull,
        );
        expect(
          await vm.probeApiConnection(
            id: first.id,
            url: 'https://attacker.test/v1',
            model: 'm',
            key: '',
            noKey: false,
            jsonMode: false,
          ),
          isFalse,
        );
        expect(await keys.read(first.profile.credentialRef), 'private');
        expect(vm.connections.items, hasLength(1));
        final data =
            (await deps.database
                    .customSelect(
                      "SELECT value FROM settings WHERE key='ai_connections'",
                    )
                    .getSingle())
                .read<String>('value');
        expect(jsonDecode(data), isA<Map>());
        expect(data, isNot(contains('private')));
      } finally {
        await deps.dispose();
      }
    },
  );

  test('subscription login saves first model without switching away from an API; sign-out has no fallback', () async {
    final keys = MemoryCredentials(), ai = Generator();
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: keys,
      ai: ai,
    );
    final vm = SettingsViewModel(
      deps.settings.profiles,
      keys,
      deps.settings.configure,
      ai,
      deps.coordinator,
      chatGpt: Sessions(keys),
      connectionRepository: SqlConnectionRepository(deps.database),
      applyConnectionChange: deps.practice.applyGuidanceChange,
      endPractice: deps.practice.endPractice,
    );
    try {
      final api = (await vm.saveApiConnection(
        name: 'API',
        url: 'https://api.openai.com/v1',
        model: 'api-model',
        key: 'api-key',
      ))!;
      final subscription = (await vm.connectSubscription(
        name: 'My subscription',
      ))!;
      expect(subscription.profile.model, 'first-model');
      expect(vm.connections.activeId, api.id);
      expect(ai.probes, 0);
      await vm.probeSubscription(
        subscription.profile.credentialRef,
        'second-model',
      );
      expect(vm.connections.activeId, api.id);
      await vm.activateConnection(subscription.id);
      await vm.disconnectSubscription(subscription.profile.credentialRef);
      expect(vm.connections.activeId, isNull);
      expect(vm.connections.find(subscription.id)!.needsLogin, isTrue);
      expect(await vm.activateConnection(subscription.id), isFalse);
      expect(await keys.read(api.profile.credentialRef), 'api-key');
    } finally {
      vm.dispose();
      await deps.dispose();
    }
  });
}
