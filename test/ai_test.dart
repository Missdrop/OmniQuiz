import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omniquiz/application/generation/question_validator.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/ai/chat_completions_generator.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';

import 'persistence_test.dart' show chunk;

class MemoryCredentials implements CredentialStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String reference) async => values[reference];
  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

Map<String, dynamic> candidate({
  String quote = 'Water freezes at zero degrees Celsius.',
}) => {
  'prompt': 'At which temperature does water freeze?',
  'options': [
    {'id': 'a', 'text': '0°C'},
    {'id': 'b', 'text': '10°C'},
    {'id': 'c', 'text': '20°C'},
    {'id': 'd', 'text': '30°C'},
  ],
  'correctOptionId': 'a',
  'explanation': 'The source states zero degrees.',
  'topic': 'Water',
  'sourceId': chunk.id,
  'quote': quote,
};
GenerationRequest request({List<String> recent = const []}) =>
    GenerationRequest(
      profile: ProviderProfile(
        baseUrl: 'https://example.com/v1',
        model: 'model',
        credentialRef: 'key',
      ),
      chunks: [chunk],
      count: 10,
      recentPrompts: recent,
    );
void main() {
  final validator = QuestionValidator(const UuidGenerator());
  test('rejects fabricated citations, duplicate questions and multiple-answer options', () {
    expect(
      () =>
          validator.validate([candidate(quote: 'The sun is blue.')], request()),
      throwsA(isA<AppFailure>()),
    );
    final valid = candidate();
    expect(validator.validate([valid, valid], request()), hasLength(1));
    expect(
      () => validator.validate([valid], request(recent: [valid['prompt']])),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => validator.validate([
        {...valid, 'correctOptionId': 'missing'},
      ], request()),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'sends only selected excerpts and parses a compatible response',
    () async {
      final keys = MemoryCredentials();
      await keys.write('key', 'test-secret');
      final generator = ChatCompletionsGenerator(
        keys,
        validator,
        clientFactory: () => MockClient((r) async {
          expect(r.url.path, '/v1/chat/completions');
          expect(r.headers['Authorization'], 'Bearer test-secret');
          expect(r.followRedirects, false);
          final body = jsonDecode(r.body);
          expect(body['model'], 'model');
          expect(body['messages'][1]['content'], contains(chunk.text));
          expect(
            jsonDecode(body['messages'][1]['content'])['language'],
            '简体中文',
          );
          expect(
            body['messages'][0]['content'],
            contains('in the requested language'),
          );
          expect(body['messages'][0]['content'], contains('quote verbatim'));
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'questions': [candidate()],
                    }),
                  },
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await generator.generate(request()), hasLength(1));
    },
  );
  test('does not expose provider error bodies or keys', () async {
    final keys = MemoryCredentials();
    await keys.write('key', 'test-secret');
    final generator = ChatCompletionsGenerator(
      keys,
      validator,
      clientFactory: () => MockClient(
        (r) async => http.Response('test-secret private content', 401),
      ),
    );
    await expectLater(
      generator.generate(request()),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('test-secret')),
        ),
      ),
    );
  });
}
