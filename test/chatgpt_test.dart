// OAuth identity, token refresh, revocation and subscription transport using deterministic HTTP fixtures.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_http.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_identity.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_login.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_sessions.dart';
import 'package:omniquiz/infrastructure/ai/chatgpt_responses.dart';
import 'package:omniquiz/infrastructure/ai/chat_completions_generator.dart';
import 'package:omniquiz/application/generation/question_validator.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';
import 'package:omniquiz/infrastructure/persistence/codec.dart';

import 'ai_test.dart' show MemoryCredentials, candidate;
import 'persistence_test.dart' show chunk;

String event(String type, [Map<String, dynamic> body = const {}]) =>
    'data: ${jsonEncode({'type': type, ...body})}\n\n';
Stream<List<int>> wire(String text) =>
    Stream.fromIterable(utf8.encode(text).map((byte) => [byte]));

void main() {
  test('loopback callback checks state and issued client, uses fresh PKCE and nonce', () async {
    late Uri started;
    final login = ChatGptLogin(
      launch: (uri) async {
        started = uri;
        final q = uri.queryParameters;
        expect(q['client_id'], 'dynamic_agent_client');
        expect(q['agent_name_hint'], 'OmniQuiz');
        expect(q['code_challenge_method'], 'S256');
        expect(q['nonce'], isNotEmpty);
        final callback = Uri.parse(q['redirect_uri']!);
        expect(callback.host, '127.0.0.1');
        final wrong = await http.get(
          callback.replace(
            queryParameters: {
              'state': 'wrong',
              'code': 'code',
              'client_id': 'oaiapp_test',
            },
          ),
        );
        expect(wrong.statusCode, 400);
        final valid = await http.get(
          callback.replace(
            queryParameters: {
              'state': q['state']!,
              'code': 'code',
              'client_id': 'oaiapp_test',
            },
          ),
        );
        expect(valid.statusCode, 200);
        expect(valid.body, isNot(contains('code')));
        return true;
      },
    );
    final result = await login.authorize('urn:uuid:test');
    expect(result['redirect_uri'], started.queryParameters['redirect_uri']);
    expect(result['client_id'], 'oaiapp_test');
    expect(
      result['code_verifier'],
      isNot(started.queryParameters['code_challenge']),
    );
  });

  test('denial, client mismatch and timeout cannot complete sign-in', () async {
    for (final params in [
      {'error': 'access_denied'},
      {'code': 'x', 'client_id': 'oaiapp_other'},
    ]) {
      final login = ChatGptLogin(
        launch: (uri) async {
          final q = uri.queryParameters;
          await http.get(
            Uri.parse(q['redirect_uri']!)
                .replace(queryParameters: {...params, 'state': q['state']!}),
          );
          return true;
        },
      );
      await expectLater(
        login.authorize('host', clientId: 'oaiapp_test'),
        throwsA(isA<AppFailure>()),
      );
    }
    final login = ChatGptLogin(
      launch: (_) async => true,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(login.authorize('host'), throwsA(isA<AppFailure>()));
  });

  final key = JsonWebKey.fromJson({
    ...JsonWebKey.generate('RS256', keyBitLength: 2048).toJson(),
    'kid': 'test',
  });
  String signed(Map<String, dynamic> claims) =>
      (JsonWebSignatureBuilder()
            ..jsonContent = claims
            ..addRecipient(key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
  Map<String, dynamic> claims({String nonce = 'nonce'}) => {
    'iss': 'https://auth.openai.com',
    'aud': 'oaiapp_test',
    'sub': 'account',
    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    'nonce': nonce,
  };
  final publicKey = Map<String, dynamic>.from(
    key.toJson(),
  )..removeWhere((name, _) => ['d', 'p', 'q', 'dp', 'dq', 'qi'].contains(name));
  test('registration exchanges the issued client and persists an independent session', () async {
    final storage = MemoryCredentials();
    String? nonce, redirect;
    final login = ChatGptLogin(
      launch: (uri) async {
        nonce = uri.queryParameters['nonce'];
        redirect = uri.queryParameters['redirect_uri'];
        await http.get(
          Uri.parse(redirect!).replace(
            queryParameters: {
              'state': uri.queryParameters['state']!,
              'client_id': 'oaiapp_test',
              'code': 'one-use-code',
            },
          ),
        );
        return true;
      },
    );
    final transport = ChatGptHttp(
      factory: () => MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          expect(request.bodyFields['client_id'], 'oaiapp_test');
          expect(request.bodyFields['redirect_uri'], redirect);
          expect(request.bodyFields['code_verifier'], isNotEmpty);
          return http.Response(
            jsonEncode({
              'access_token': 'plan-access',
              'refresh_token': 'plan-refresh',
              'id_token': signed(claims(nonce: nonce!)),
              'token_type': 'Bearer',
              'expires_in': 3600,
              'scope':
                  'chatgpt.tokens.use.direct resource.invoke offline_access',
            }),
            200,
          );
        }
        if (request.url.path == '/v1/models') {
          expect(request.headers['Authorization'], 'Bearer plan-access');
          return http.Response(
            '{"models":[{"slug":"available","visibility":"list"},{"slug":"hidden","visibility":"hidden"}]}',
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'keys': [publicKey],
          }),
          200,
        );
      }),
    );
    final sessions = ChatGptSessions(storage, http: transport, login: login);
    expect(await sessions.signIn(), 'oaiapp_test');
    final reopened = ChatGptSessions(storage, http: transport);
    expect(await reopened.access('oaiapp_test'), 'plan-access');
    expect(await reopened.models('oaiapp_test'), ['available']);
    expect(storage.values['omniquiz.chatgpt.host'], startsWith('urn:uuid:'));
  });
  test(
    'identity requires a valid signature, audience, nonce, subject and expiry',
    () async {
      final identity = ChatGptIdentity(
        ChatGptHttp(
          factory: () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'keys': [publicKey],
              }),
              200,
            ),
          ),
        ),
      );
      expect(
        (await identity.verify(
          signed(claims()),
          'oaiapp_test',
          nonce: 'nonce',
        ))['sub'],
        'account',
      );
      for (final invalid in [
        {...claims(), 'aud': 'other'},
        {...claims(), 'nonce': 'other'},
        {...claims(), 'exp': 0},
        {...claims(), 'iss': 'https://other.example'},
        {...claims(), 'sub': 'other'},
      ]) {
        await expectLater(
          identity.verify(
            signed(invalid),
            'oaiapp_test',
            nonce: 'nonce',
            subject: 'account',
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      final token = signed(claims());
      await expectLater(
        identity.verify(
          '${token.substring(0, token.lastIndexOf('.') + 1)}AAAA',
          'oaiapp_test',
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('SSE handles split UTF-8 and rejects partial text followed by failure or disconnect', () async {
    final text =
        event('response.output_text.delta', {'delta': '中文'}) +
        event('response.completed', {
          'response': {'status': 'completed'},
        });
    expect(await ChatGptResponses.readEvents(wire(text)), '中文');
    for (final tail in [
      '',
      event('response.failed'),
      event('response.incomplete'),
      event('error'),
    ]) {
      await expectLater(
        ChatGptResponses.readEvents(
          wire(
            event('response.output_text.delta', {'delta': 'partial'}) + tail,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    }
  });

  test('rotated credentials survive JWKS failure; refresh is serialized and logout clears tokens', () async {
    final storage = MemoryCredentials();
    await storage.write(
      'omniquiz.chatgpt.accounts.v1',
      jsonEncode({
        'oaiapp_test': {
          'sub': 'account',
          'verified': true,
          'access_token': 'old',
          'refresh_token': 'refresh-old',
          'expires_at': 0,
          'scope': 'chatgpt.tokens.use.direct resource.invoke',
        },
      }),
    );
    var refreshes = 0, failJwks = true;
    final transport = ChatGptHttp(
      factory: () => MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          refreshes++;
          expect(request.bodyFields['refresh_token'], 'refresh-old');
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return http.Response(
            jsonEncode({
              'access_token': 'new',
              'refresh_token': 'refresh-new',
              'id_token': signed(claims()),
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/revoke')) {
          expect(request.bodyFields['token'], 'refresh-new');
          return http.Response('', 200);
        }
        if (failJwks) return http.Response('', 503);
        return http.Response(
          jsonEncode({
            'keys': [publicKey],
          }),
          200,
        );
      }),
    );
    final sessions = ChatGptSessions(storage, http: transport);
    await expectLater(
      Future.wait([
        sessions.access('oaiapp_test'),
        sessions.access('oaiapp_test'),
      ]),
      throwsA(isA<AppFailure>()),
    );
    expect(refreshes, 1);
    expect(storage.values.values.single, contains('refresh-new'));
    failJwks = false;
    expect(await sessions.access('oaiapp_test'), 'new');
    expect(refreshes, 1);
    expect(await sessions.signOut('oaiapp_test'), true);
    expect(storage.values.values.single, isNot(contains('refresh-new')));
    expect(await sessions.accounts(), contains('oaiapp_test'));
    await expectLater(
      sessions.access('oaiapp_test'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('direct generation uses fixed Responses endpoint, no API key, and validates source evidence', () async {
    final storage = MemoryCredentials();
    await storage.write(
      'omniquiz.chatgpt.accounts.v1',
      jsonEncode({
        'oaiapp_test': {
          'sub': 'account',
          'verified': true,
          'access_token': 'oauth',
          'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
        },
      }),
    );
    final profile = ProviderProfile(
      baseUrl: 'https://api.openai.com/v1',
      model: 'selected',
      credentialRef: 'oaiapp_test',
      chatGpt: true,
    );
    expect(profileFromJson(profileToJson(profile)).chatGpt, true);
    expect(jsonEncode(profileToJson(profile)), isNot(contains('oauth')));
    final generator = ChatCompletionsGenerator(
      storage,
      QuestionValidator(const UuidGenerator()),
      chatGpt: ChatGptResponses(
        ChatGptSessions(storage),
        factory: () => MockClient((request) async {
          expect(request.url.toString(), 'https://api.openai.com/v1/responses');
          expect(request.headers['Authorization'], 'Bearer oauth');
          expect(request.followRedirects, false);
          final body = jsonDecode(request.body);
          expect(body['store'], false);
          expect(body['stream'], true);
          expect(body['input'][0]['role'], 'developer');
          expect(body.containsKey('temperature'), false);
          return http.Response(
            event('response.output_text.delta', {
                  'delta': jsonEncode({
                    'questions': [candidate()],
                  }),
                }) +
                event('response.completed', {
                  'response': {'status': 'completed'},
                }),
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      ),
    );
    final questions = await generator.generate(
      GenerationRequest(
        profile: profile,
        chunks: [chunk],
        count: 1,
        recentPrompts: const [],
      ),
    );
    expect(questions, hasLength(1));
  });
}
