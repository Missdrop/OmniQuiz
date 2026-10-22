import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

/// Owns transport, bounded response reading and provider failure translation.
/// It never stores documents or decides whether another paid request is made.
class ChatCompletionsClient {
  ChatCompletionsClient({
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 90),
  }) : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  final Duration timeout;
  final Set<http.Client> _active = {};

  Future<String> complete(
    ProviderProfile profile,
    String key,
    List<Map<String, String>> messages,
  ) async {
    final client = _factory();
    _active.add(client);
    try {
      return await _request(client, profile, key, messages).timeout(timeout);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(
        'Generation timed out. A retry may incur another API charge.',
      );
    } on FormatException {
      throw const AppFailure('The provider returned invalid JSON.');
    } on TypeError {
      throw const AppFailure(
        'The provider response is not compatible with Chat Completions.',
      );
    } catch (_) {
      // The remote server may have received and billed an interrupted request.
      throw const AppFailure(
        'Could not reach the provider. Check your connection and API address.',
      );
    } finally {
      _active.remove(client);
      client.close();
    }
  }

  Future<String> _request(
    http.Client client,
    ProviderProfile profile,
    String key,
    List<Map<String, String>> messages,
  ) async {
    final request = http.Request('POST', profile.completionsUri)
      ..followRedirects = false
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (key.isNotEmpty) 'Authorization': 'Bearer $key',
      })
      ..body = jsonEncode({
        'model': profile.model,
        'messages': messages,
        if (profile.jsonMode) 'response_format': {'type': 'json_object'},
      });
    final response = await client.send(request);
    _checkStatus(response);
    final data = jsonDecode(await _read(response)) as Map<String, dynamic>;
    final choice = (data['choices'] as List).first;
    if (choice['finish_reason'] == 'length') {
      throw const AppFailure(
        'Provider output was truncated. Try a model with a larger output limit.',
      );
    }
    return choice['message']['content'] as String;
  }

  void _checkStatus(http.StreamedResponse response) {
    switch (response.statusCode) {
      case 200:
        return;
      case 401:
      case 403:
        throw const AppFailure(
          'API authorization failed. Check your key and model access.',
        );
      case 429:
        throw AppFailure(
          'Provider rate limit or quota reached. Try again later.',
          retryable: true,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      default:
        if (response.statusCode >= 500) {
          throw const AppFailure(
            'The AI provider is temporarily unavailable.',
            retryable: true,
          );
        }
        throw AppFailure(
          'Provider returned HTTP ${response.statusCode}. Check the base URL, model and JSON mode.',
        );
    }
  }

  Future<String> _read(http.StreamedResponse response) async {
    final bytes = <int>[];
    await for (final part in response.stream) {
      if (bytes.length + part.length > 2 * 1024 * 1024) {
        throw const AppFailure('Provider response exceeded the size limit.');
      }
      bytes.addAll(part);
    }
    return utf8.decode(bytes);
  }

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final delay = HttpDate.parse(value).difference(DateTime.now().toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } catch (_) {
      return null;
    }
  }

  void cancel() {
    for (final client in _active.toList()) {
      client.close();
    }
    _active.clear();
  }
}
