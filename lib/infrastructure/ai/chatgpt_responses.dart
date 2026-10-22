import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';
import 'chatgpt_sessions.dart';

class ChatGptResponses {
  ChatGptResponses(this.sessions, {http.Client Function()? factory})
    : factory = factory ?? http.Client.new;
  final ChatGptSessions sessions;
  final http.Client Function() factory;
  final _active = <http.Client>{};
  int _epoch = 0;
  Future<String> complete(
    ProviderProfile profile,
    List<Map<String, String>> messages,
  ) async {
    final epoch = _epoch;
    final token = await sessions.access(profile.credentialRef);
    if (epoch != _epoch) {
      throw const AppFailure(
        'ChatGPT request was interrupted. Please try again.',
      );
    }
    final client = factory();
    _active.add(client);
    try {
      return await (() async {
        final request =
            http.Request(
                'POST',
                Uri.parse('https://api.openai.com/v1/responses'),
              )
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              })
              ..body = jsonEncode({
                'model': profile.model,
                'store': false,
                'stream': true,
                'input': [
                  for (final message in messages)
                    {
                      ...message,
                      'role': message['role'] == 'system'
                          ? 'developer'
                          : message['role'],
                    },
                ],
              });
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw const AppFailure(
            'ChatGPT request failed. Sign in again or check your plan access.',
          );
        }
        return await readEvents(response.stream);
      })().timeout(const Duration(seconds: 120));
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'ChatGPT request was interrupted. Please try again.',
      );
    } finally {
      _active.remove(client);
      client.close();
    }
  }

  static Future<String> readEvents(Stream<List<int>> stream) async {
    var bytes = 0;
    final bounded = stream.map((part) {
      bytes += part.length;
      if (bytes > 4 * 1024 * 1024) {
        throw const AppFailure('Provider response exceeded the size limit.');
      }
      return part;
    });
    final data = <String>[];
    final text = StringBuffer();
    await for (final line
        in bounded.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.startsWith('data:')) data.add(line.substring(5).trimLeft());
      if (line.isNotEmpty || data.isEmpty) continue;
      final event = jsonDecode(data.join('\n')) as Map<String, dynamic>;
      data.clear();
      switch (event['type']) {
        case 'response.output_text.delta':
          text.write(event['delta'] as String);
        case 'response.completed':
          if (event['response']?['status'] != 'completed' || text.isEmpty) {
            throw const FormatException();
          }
          return text.toString();
        case 'response.failed':
        case 'response.incomplete':
        case 'error':
          throw const AppFailure(
            'ChatGPT could not complete the response. Check your plan usage and try again.',
          );
      }
    }
    throw const AppFailure(
      'ChatGPT request was interrupted. Please try again.',
    );
  }

  void cancel() {
    _epoch++;
    for (final client in _active.toList()) {
      client.close();
    }
    _active.clear();
  }
}
