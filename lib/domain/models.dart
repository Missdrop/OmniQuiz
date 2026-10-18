// SPDX-License-Identifier: GPL-3.0-only

class AppFailure implements Exception {
  const AppFailure(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

class SourceChunk {
  const SourceChunk({
    required this.id,
    required this.documentId,
    required this.documentName,
    required this.revision,
    required this.location,
    required this.text,
  });
  final String id, documentId, documentName, revision, location, text;
}

class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.name,
    required this.revision,
    required this.origin,
    required this.importedAt,
    required this.chunkCount,
  });
  final String id, name, revision, origin;
  final DateTime importedAt;
  final int chunkCount;
}

class AnswerOption {
  const AnswerOption(this.id, this.text);
  final String id, text;
}

class Question {
  Question({
    required this.id,
    required this.prompt,
    required List<AnswerOption> options,
    required this.correctOptionId,
    required this.explanation,
    required this.topic,
    required this.source,
    required this.quote,
    this.flagged = false,
    this.stale = false,
  }) : options = List.unmodifiable(options) {
    if (prompt.trim().isEmpty ||
        explanation.trim().isEmpty ||
        topic.trim().isEmpty ||
        options.length != 4 ||
        options.any((o) => o.text.trim().isEmpty) ||
        options.map((o) => o.id).toSet().length != options.length ||
        options.map((o) => o.text.trim().toLowerCase()).toSet().length !=
            options.length ||
        !options.any((o) => o.id == correctOptionId) ||
        quote.trim().isEmpty) {
      throw const AppFailure('The provider returned an invalid question.');
    }
  }
  final String id, prompt, correctOptionId, explanation, topic, quote;
  final List<AnswerOption> options;
  final SourceChunk source;
  final bool flagged, stale;
  bool isCorrect(String optionId) => correctOptionId == optionId;
}

class ProviderProfile {
  ProviderProfile({
    required this.baseUrl,
    required this.model,
    this.jsonMode = false,
    this.credentialRef = '',
    this.language = '简体中文',
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host))) ||
        model.trim().isEmpty) {
      throw const AppFailure(
        'Enter an HTTPS API base URL and a model name. HTTP is allowed only for localhost.',
      );
    }
  }
  final String baseUrl, model, credentialRef, language;
  final bool jsonMode;
  Uri get completionsUri =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
}

class AnswerAttempt {
  const AnswerAttempt({
    required this.id,
    required this.questionId,
    required this.optionId,
    required this.correct,
    required this.at,
  });
  final String id, questionId, optionId;
  final bool correct;
  final DateTime at;
}

class ReviewState {
  const ReviewState({
    required this.questionId,
    required this.streak,
    required this.mistakes,
    required this.dueAt,
  });
  final String questionId;
  final int streak, mistakes;
  final DateTime dueAt;
  bool get mastered => streak >= 3;
}

class ReviewEntry {
  const ReviewEntry(this.question, this.state);
  final Question question;
  final ReviewState state;
}

class StudyStats {
  const StudyStats({
    this.documents = 0,
    this.ready = 0,
    this.attempts = 0,
    this.correct = 0,
    this.review = 0,
  });
  final int documents, ready, attempts, correct, review;
}

class GenerationRequest {
  GenerationRequest({
    required this.profile,
    required List<SourceChunk> chunks,
    required this.count,
    required List<String> recentPrompts,
  }) : chunks = List.unmodifiable(chunks),
       recentPrompts = List.unmodifiable(recentPrompts);
  final ProviderProfile profile;
  final List<SourceChunk> chunks;
  final int count;
  final List<String> recentPrompts;
}

class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.epoch,
    required this.scope,
    required this.request,
    this.attempt = 0,
  });
  final String id;
  final int epoch, attempt;
  final String? scope;
  final GenerationRequest request;
}

class ImportResult {
  const ImportResult(this.imported, this.unchanged, this.errors);
  final int imported, unchanged;
  final List<String> errors;
}
