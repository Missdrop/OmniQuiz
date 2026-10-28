// Builds one source-grounded prompt for API and subscription transports, then validates its output.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/generation/question_validator.dart';
import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import 'chat_completions_client.dart';
import 'chatgpt_responses.dart';
import 'study_prompt.dart';

/// Prepares study prompts and validates untrusted output; transport is separate.
class ChatCompletionsGenerator implements AiQuestionGenerator {
  ChatCompletionsGenerator(
    this.credentials,
    this.validator, {
    http.Client Function()? clientFactory,
    Duration requestTimeout = const Duration(minutes: 3),
    this.chatGpt,
    this.onProgress,
  }) : _client = ChatCompletionsClient(
         clientFactory: clientFactory,
         timeout: requestTimeout,
       );
  final CredentialStore credentials;
  final QuestionValidator validator;
  final ChatCompletionsClient _client;
  final ChatGptResponses? chatGpt;
  final void Function(String)? onProgress;
  int _generationEpoch = 0;
  Future<String> _complete(
    ProviderProfile profile,
    String key,
    List<Map<String, String>> messages,
  ) {
    switch (profile.type) {
      case AiConnectionType.chatGptSubscription:
        if (chatGpt == null) {
          throw const AppFailure('Sign in to ChatGPT in Settings first.');
        }
        return chatGpt!.complete(profile, messages);
      case AiConnectionType.openAiCompatible:
        return _client.complete(profile, key, messages);
    }
  }

  @override
  Future<void> probe(ProviderProfile profile, String apiKey) async {
    final content = await _complete(profile, apiKey, [
      {'role': 'user', 'content': 'Return only this JSON object: {"ok":true}'},
    ]);
    final result = _decode(content);
    if (result['ok'] != true) {
      throw const AppFailure(
        'The model responded, but did not follow the JSON test. Try another model.',
      );
    }
  }

  Map<String, dynamic> _decode(String text) {
    var value = text.trim();
    if (value.startsWith('```')) {
      value = value
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      throw const AppFailure(
        'The model did not return valid JSON. Try JSON mode or a different model.',
      );
    }
  }

  @override
  Future<List<Question>> generate(GenerationRequest request) async {
    final epoch = _generationEpoch;
    void report(String message) {
      if (epoch == _generationEpoch) onProgress?.call(message);
    }

    String? key;
    try {
      key = request.profile.chatGpt
          ? ''
          : await credentials.read(request.profile.credentialRef);
    } catch (_) {
      throw const AppFailure(
        'Cannot access secure storage. Unlock your device and try again.',
      );
    }
    if (key == null) {
      throw const AppFailure(
        'API credentials are missing. Save them in Settings.',
      );
    }
    report('Waiting for the model to write questions…');
    final content = await _complete(
      request.profile,
      key,
      buildStudyMessages(request),
    );
    report('Checking answers, citations and duplicates…');
    final candidates = _decode(content)['questions'];
    if (candidates is! List) {
      throw const AppFailure('The provider returned no question list.');
    }
    return validator.validate(candidates, request);
  }

  @override
  void cancel() {
    _generationEpoch++;
    _client.cancel();
    chatGpt?.cancel();
  }
}
