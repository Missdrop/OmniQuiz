// Provider changes and secure credential reuse distinguish user input errors from transport failures.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/application/use_cases/configure_provider.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';

import 'ai_test.dart' show MemoryCredentials;

void main() {
  test('keeps keys out of profile data and prevents silent reuse at another endpoint', () async {
    final db = QuizDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profiles = SqlProfileRepository(db), keys = MemoryCredentials();
    final useCase = ConfigureProvider(profiles, keys, const UuidGenerator());
    Future<void> save(String endpoint, String key) => useCase.save(
      baseUrl: endpoint,
      model: 'test',
      key: key,
      jsonMode: false,
      language: 'English',
    );
    await save('https://one.example/v1', 'private-test-key');
    final original = (await profiles.load())!;
    expect(await keys.read(original.credentialRef), 'private-test-key');
    final payload =
        (await db
                .customSelect("SELECT value FROM settings WHERE key='profile'")
                .getSingle())
            .read<String>('value');
    expect(payload, isNot(contains('private-test-key')));
    await save('https://one.example/v1', '');
    expect((await profiles.load())!.credentialRef, original.credentialRef);
    await expectLater(
      save('https://two.example/v1', ''),
      throwsA(isA<AppFailure>()),
    );
    expect((await profiles.load())!.baseUrl, 'https://one.example/v1');
    await save('https://two.example/v1', 'replacement');
    expect(await keys.read(original.credentialRef), isNull);
  });
}
