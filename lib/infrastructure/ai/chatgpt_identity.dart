// Verifies signed identity tokens and binds claims to the expected client and login attempt.

import 'dart:convert';

import 'package:jose/jose.dart';

import '../../domain/models.dart';
import 'chatgpt_http.dart';

/// Validates RSA signatures, issuer, audience, lifetime and login-bound identity claims.
class ChatGptIdentity {
  ChatGptIdentity(this.http);
  final ChatGptHttp http;

  /// Verifies signatures before exposing claims; decoding a JWT alone proves nothing.
  Future<Map<String, dynamic>> verify(
    String token,
    String clientId, {
    String? nonce,
    String? subject,
  }) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      if (header['alg'] != 'RS256') throw const FormatException();
      final keys = await http.json(
        'https://auth.openai.com/.well-known/jwks.json',
      );
      final store = JsonWebKeyStore();
      for (final key in keys['keys'] as List) {
        if (key['kty'] == 'RSA' && key['kid'] == header['kid']) {
          store.addKey(JsonWebKey.fromJson(Map<String, dynamic>.from(key)));
        }
      }
      final jwt = JsonWebToken.unverified(token);
      if (!await jwt.verify(store)) throw const FormatException();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final audience = claims['aud'];
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (claims['iss'] != 'https://auth.openai.com' ||
          !(audience == clientId ||
              audience is List && audience.contains(clientId)) ||
          (audience is List &&
              audience.length > 1 &&
              claims['azp'] != clientId) ||
          claims['exp'] is! num ||
          (claims['exp'] as num) <= now ||
          (claims['nbf'] is num && (claims['nbf'] as num) > now + 60) ||
          claims['sub'] is! String ||
          (claims['sub'] as String).isEmpty ||
          (nonce != null && claims['nonce'] != nonce) ||
          (subject != null && claims['sub'] != subject)) {
        throw const FormatException();
      }
      return claims;
    } catch (_) {
      throw const AppFailure(
        'ChatGPT identity could not be verified. Please sign in again.',
      );
    }
  }
}
