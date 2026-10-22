import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

/// Fixed-host OAuth requests; no redirects, secrets in diagnostics, or retries.
class ChatGptHttp {
  ChatGptHttp({http.Client Function()? factory})
    : factory = factory ?? http.Client.new;
  final http.Client Function() factory;
  Future<Map<String, dynamic>> json(
    String url, {
    Map<String, String>? form,
    String? bearer,
  }) async {
    final client = factory();
    try {
      return await (() async {
        final request = http.Request(
          form == null ? 'GET' : 'POST',
          Uri.parse(url),
        )..followRedirects = false;
        if (form != null) request.bodyFields = form;
        if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw const AppFailure(
            'ChatGPT request failed. Sign in again or check your plan access.',
          );
        }
        final bytes = <int>[];
        await for (final part in response.stream) {
          if (bytes.length + part.length > 1024 * 1024) {
            throw const FormatException();
          }
          bytes.addAll(part);
        }
        return bytes.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 30));
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'ChatGPT request failed. Sign in again or check your plan access.',
      );
    } finally {
      client.close();
    }
  }
}
