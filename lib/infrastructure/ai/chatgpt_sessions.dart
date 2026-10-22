import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import 'chatgpt_http.dart';
import 'chatgpt_identity.dart';
import 'chatgpt_login.dart';

/// OAuth credentials never enter ProviderProfile, jobs, SQLite or backups.
class ChatGptSessions {
  ChatGptSessions(
    this.storage, {
    ChatGptHttp? http,
    ChatGptLogin? login,
    ChatGptIdentity? identity,
  }) : http = http ?? ChatGptHttp(),
       login = login ?? ChatGptLogin(),
       identity = identity ?? ChatGptIdentity(http ?? ChatGptHttp());
  final CredentialStore storage;
  final ChatGptHttp http;
  final ChatGptLogin login;
  final ChatGptIdentity identity;
  String? lastRegistration;
  int _authEpoch = 0;
  void cancelLogin() {
    _authEpoch++;
    login.cancel();
  }

  static const _key = 'omniquiz.chatgpt.accounts.v1';
  final _refreshing = <String, Future<String>>{};
  Future<Map<String, dynamic>> _load() async {
    final text = await storage.read(_key);
    return text == null ? {} : jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _save(Map<String, dynamic> accounts) =>
      storage.write(_key, jsonEncode(accounts));
  Future<Map<String, String>> accounts() async => (await _load()).map(
    (id, record) => MapEntry(
      id,
      '${record['email'] ?? record['sub']} · ${id.substring(id.length > 6 ? id.length - 6 : 0)}',
    ),
  );

  Future<String> signIn({String? clientId}) async {
    lastRegistration = null;
    final epoch = _authEpoch;
    void checkCurrent() {
      if (epoch != _authEpoch) {
        throw const AppFailure(
          'ChatGPT sign-in was cancelled or expired. Please try again.',
        );
      }
    }

    var host = await storage.read('omniquiz.chatgpt.host');
    if (host == null) {
      host = 'urn:uuid:${const Uuid().v4()}';
      await storage.write('omniquiz.chatgpt.host', host);
    }
    final accounts = await _load();
    final old = clientId == null
        ? null
        : accounts[clientId] as Map<String, dynamic>?;
    if (clientId != null && old == null) throw const FormatException();
    checkCurrent();
    final callback = await login.authorize(host, clientId: clientId);
    checkCurrent();
    final issued = callback['client_id']!;
    lastRegistration = issued;
    // Retain the issued registration even if the single-use exchange fails.
    accounts.putIfAbsent(
      issued,
      () => <String, dynamic>{'sub': 'Registration pending'},
    );
    await _save(accounts);
    final tokens = await http.json(
      'https://auth.openai.com/api/accounts/oauth/token',
      form: {
        'grant_type': 'authorization_code',
        'client_id': issued,
        'code': callback['code']!,
        'code_verifier': callback['code_verifier']!,
        'redirect_uri': callback['redirect_uri']!,
        'resource': 'https://api.openai.com/v1',
      },
    );
    checkCurrent();
    final claims = await identity.verify(
      tokens['id_token'] as String,
      issued,
      nonce: callback['nonce'],
      subject: old?['verified'] == true ? old!['sub'] as String : null,
    );
    checkCurrent();
    final record = _tokens(tokens, {}, requireScope: true)
      ..addAll({
        'sub': claims['sub'],
        'email': claims['email'],
        'verified': true,
        'pending': false,
      });
    accounts[issued] = record;
    await _save(accounts);
    return issued;
  }

  Map<String, dynamic> _tokens(
    Map<String, dynamic> result,
    Map<String, dynamic> old, {
    bool requireScope = false,
  }) {
    if (result['access_token'] is! String ||
        (result['access_token'] as String).isEmpty ||
        result['token_type']?.toString().toLowerCase() != 'bearer' ||
        result['expires_in'] is! num) {
      throw const FormatException();
    }
    final scopes = result['scope'] ?? (requireScope ? '' : old['scope']);
    if (scopes is! String ||
        !scopes.split(' ').contains('chatgpt.tokens.use.direct') ||
        !scopes.split(' ').contains('resource.invoke')) {
      throw const AppFailure(
        'ChatGPT plan access was not granted. Enable it when signing in.',
      );
    }
    return {
      ...old,
      ...result,
      'scope': scopes,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch +
          (result['expires_in'] as num).toInt() * 1000,
    };
  }

  Future<String> access(String id) => _refreshing.putIfAbsent(
    id,
    () => _access(id).whenComplete(() {
      _refreshing.remove(id);
    }),
  );
  Future<String> _access(String id) async {
    final accounts = await _load();
    var record = accounts[id] as Map<String, dynamic>?;
    if (record == null ||
        record['verified'] != true ||
        record['access_token'] == null) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
    if (record['pending'] == true) {
      await identity.verify(
        record['id_token'] as String,
        id,
        subject: record['sub'] as String,
      );
      record['pending'] = false;
      await _save(accounts);
    }
    if ((record['expires_at'] as int) >
        DateTime.now().millisecondsSinceEpoch + 60000) {
      return record['access_token'] as String;
    }
    if (record['refresh_token'] is! String) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
    final result = await http.json(
      'https://auth.openai.com/api/accounts/oauth/token',
      form: {
        'grant_type': 'refresh_token',
        'client_id': id,
        'refresh_token': record['refresh_token'] as String,
        'resource': 'https://api.openai.com/v1',
      },
    );
    record = _tokens(result, record)..['pending'] = result['id_token'] != null;
    // Persist rotated refresh tokens before JWKS I/O; never reuse a consumed one.
    accounts[id] = record;
    await _save(accounts);
    if (record['pending'] == true) {
      await identity.verify(
        record['id_token'] as String,
        id,
        subject: record['sub'] as String,
      );
      record['pending'] = false;
      await _save(accounts);
    }
    return record['access_token'] as String;
  }

  Future<List<String>> models(String id) async {
    final response = await http.json(
      'https://api.openai.com/v1/models',
      bearer: await access(id),
    );
    return [
      for (final model in response['models'] as List)
        if (model['visibility'] == 'list' && model['slug'] is String)
          model['slug'] as String,
    ];
  }

  Future<bool> signOut(String id) async {
    final inFlight = _refreshing[id];
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {}
    }
    final accounts = await _load();
    final record = accounts[id] as Map<String, dynamic>?;
    if (record == null) return true;
    var revoked = true;
    if (record['refresh_token'] is String) {
      try {
        await http.json(
          'https://auth.openai.com/api/accounts/oauth/revoke',
          form: {
            'client_id': id,
            'token': record['refresh_token'] as String,
            'token_type_hint': 'refresh_token',
          },
        );
      } catch (_) {
        revoked = false;
      }
    }
    accounts[id] = {
      'sub': record['sub'],
      'email': record['email'],
      'verified': record['verified'],
    };
    await _save(accounts);
    return revoked;
  }
}
