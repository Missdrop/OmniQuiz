// SPDX-License-Identifier: GPL-3.0-only

// Immutable study and generation data; source revisions bind questions to their supporting evidence.

import 'failure.dart';
import 'generation_guidance.dart';
export 'failure.dart';

/// A revision-bound excerpt that may be cited as evidence in generated questions.
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

/// The currently imported revision of one original material.
class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.name,
    required this.revision,
    required this.origin,
    required this.importedAt,
    required this.chunkCount,
    this.enabled = true,
  });
  final String id, name, revision, origin;
  final DateTime importedAt;
  final int chunkCount;
  final bool enabled;
}

/// One saved answer, including its question snapshot and original evidence.
class AnswerRecord {
  const AnswerRecord(this.question, this.attempt);
  final Question question;
  final AnswerAttempt attempt;
}

/// One stable option identifier and its user-visible text.
class AnswerOption {
  const AnswerOption(this.id, this.text);
  final String id, text;
}

/// Local question-quality feedback is independent from whether an answer was correct.
enum QuestionRating { good, bad, error }

/// A bounded quality example for subsequent batches, never factual evidence.
class QuestionFeedback {
  const QuestionFeedback({
    required this.rating,
    required this.prompt,
    required this.options,
    required this.explanation,
    required this.note,
  });
  final QuestionRating rating;
  final String prompt, explanation, note;
  final List<String> options;
  Map<String, dynamic> toJson() => {
    'rating': rating.name,
    'prompt': prompt,
    'options': options,
    'explanation': explanation,
    'note': note,
  };
}

/// A four-option question with one correct answer and a source-backed quote.
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

/// API gateways use the same transport as the official OpenAI API.
enum AiConnectionType { chatGptSubscription, openAiCompatible }

/// Non-secret connection settings; credentials are addressed only by an opaque reference.
class ProviderProfile {
  ProviderProfile({
    required this.baseUrl,
    required this.model,
    this.jsonMode = false,
    this.credentialRef = '',
    this.language = '简体中文',
    bool chatGpt = false,
    AiConnectionType? type,
  }) : type =
           type ??
           (chatGpt
               ? AiConnectionType.chatGptSubscription
               : AiConnectionType.openAiCompatible) {
    if (this.chatGpt &&
        (baseUrl != 'https://api.openai.com/v1' ||
            !credentialRef.startsWith('oaiapp_'))) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
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
  final AiConnectionType type;
  bool get chatGpt => type == AiConnectionType.chatGptSubscription;
  Uri get completionsUri =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
}

/// An idempotently identified answer event, separate from the mutable question view.
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

/// Spaced-review progress and the next due instant for one question.
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

/// Combines question content with its persisted review schedule for presentation.
class ReviewEntry {
  const ReviewEntry(this.question, this.state);
  final Question question;
  final ReviewState state;
}

/// A read-only aggregate of library progress, excluding hidden or stale ready questions.
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

/// An immutable batch snapshot shared by API and subscription generation transports.
class GenerationRequest {
  GenerationRequest({
    required this.profile,
    required List<SourceChunk> chunks,
    required this.count,
    required List<String> recentPrompts,
    this.additionalRequirements = '',
    List<ReferenceExample> referenceExamples = const [],
    List<QuestionFeedback> qualityFeedback = const [],
  }) : chunks = List.unmodifiable(chunks),
       recentPrompts = List.unmodifiable(recentPrompts),
       referenceExamples = List.unmodifiable(referenceExamples),
       qualityFeedback = List.unmodifiable(qualityFeedback);
  final ProviderProfile profile;
  final List<SourceChunk> chunks;
  final int count;
  final List<String> recentPrompts;
  final String additionalRequirements;
  final List<ReferenceExample> referenceExamples;
  final List<QuestionFeedback> qualityFeedback;
}

/// A request snapshot bound to a library epoch so late responses cannot publish stale data.
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

/// Reports partial import successes without hiding per-file failures.
class ImportResult {
  const ImportResult(this.imported, this.unchanged, this.errors);
  final int imported, unchanged;
  final List<String> errors;
}
