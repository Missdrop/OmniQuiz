// Contracts between use cases and adapters; no SQL, widgets or remote provider DTOs belong here.

import '../../domain/models.dart';
import '../../domain/generation_guidance.dart';

/// Persist reference papers and authoring preferences separately from study sources.
abstract interface class GenerationGuidanceRepository {
  /// Returns empty defaults when the library has never stored guidance.
  Future<GenerationGuidance> load();

  /// Atomically persists guidance and invalidates jobs; saved questions remain intact.
  Future<void> save(GenerationGuidance value);
}

/// Owns imported revisions and source chunks, not user filesystem deletion.
abstract interface class MaterialRepository {
  /// Lists only the current imported revisions in this library.
  Future<List<StudyDocument>> documents();

  /// Looks up a stable import origin to detect unchanged or replaced files.
  Future<StudyDocument?> byOrigin(String origin);

  /// Publishes a document and all its chunks together; old-revision questions retire.
  Future<void> importDocument(StudyDocument document, List<SourceChunk> chunks);

  /// Removes imported content, never the user-owned original file.
  Future<void> removeDocument(String id);

  /// A null document ID selects excerpts across the complete library.
  Future<List<SourceChunk>> chunks(String? documentId);

  /// Selects a bounded rotating slice rather than sending the whole library to AI.
  Future<List<SourceChunk>> generationChunks(
    String? documentId,
    int cursor,
    int limit,
  );
}

/// Reads practice/review queues and records explicit question hiding.
abstract interface class QuestionRepository {
  /// Returns fresh, unhidden, unanswered questions for the selected material scope.
  Future<List<Question>> ready(String? scope);

  /// Counts the same eligible queue used by [ready] for buffer decisions.
  Future<int> readyCount(String? scope);

  /// Supplies prior prompts so inference can avoid repeating saved questions.
  Future<List<String>> recentPrompts(String? scope);

  /// Includes due and early-review entries that have not graduated or retired.
  Future<List<ReviewEntry>> reviews();

  /// Hides a question locally without notifying a developer or deleting attempts.
  Future<void> flagQuestion(String id);

  /// Reads the saved quality vote; votes never alter an answer or review schedule.
  Future<QuestionRating?> feedback(String id);

  /// Upserts a local vote. An error report also hides the question atomically.
  Future<void> rate(String id, QuestionRating rating, {String note = ''});

  /// Returns bounded recent quality examples only for current source revisions in scope.
  Future<List<QuestionFeedback>> generationFeedback(String? scope);

  /// Reads progress aggregates without changing review state.
  Future<StudyStats> stats();
}

/// Atomically stores attempts and updates spaced-review state.
abstract interface class ProgressRepository {
  /// Idempotent by attempt ID; the attempt and resulting schedule commit together.
  Future<void> submit(AnswerAttempt attempt);
}

/// Stores non-secret provider settings; a credential reference is not a credential.
abstract interface class ProfileRepository {
  /// Null means that no generation connection has been configured yet.
  Future<ProviderProfile?> load();

  /// Stores only a secret reference and invalidates incompatible queued requests.
  Future<void> save(ProviderProfile profile);
}

/// Reads and removes opaque secrets through OS-backed storage adapters.
abstract interface class CredentialStore {
  /// Returns null for a missing secret; callers distinguish this from a storage failure.
  Future<String?> read(String reference);

  /// Uses an opaque key so connection payloads never need to contain the secret.
  Future<void> write(String reference, String secret);

  /// Removes only the explicitly named credential or account record.
  Future<void> delete(String reference);
}

/// Persists leased work and atomically publishes only current-epoch results.
abstract interface class JobRepository {
  /// Monotonic library version captured by every newly prepared job.
  Future<int> epoch();

  /// Cancels interrupted work; restarting must not replay a potentially billed request.
  Future<void> recover();

  /// Persists the immutable request before any provider call is made.
  Future<void> enqueue(GenerationJob job);

  /// Acquires an eligible lease once; false means another state/epoch won the race.
  Future<bool> claim(String id, DateTime now);

  /// Commits valid results only if the job, epoch and source revisions still match.
  Future<bool> complete(GenerationJob job, List<Question> questions);

  /// Records the terminal outcome and removes the persisted request body.
  Future<void> fail(String id, String message, {bool cancelled = false});

  /// Schedules a bounded provider retry without starting another concurrent lease.
  Future<void> retry(String id, DateTime at);
}

/// Performs one cancellable inference request; retry policy belongs to the coordinator.
abstract interface class AiQuestionGenerator {
  /// Sends one batch and returns validated questions, or an explicit retryable failure.
  Future<List<Question>> generate(GenerationRequest request);

  /// Sends a small test request; it does not activate or persist the connection.
  Future<void> probe(ProviderProfile profile, String apiKey);

  /// Aborts transport work; callers must also reject responses that already completed.
  void cancel();
}

/// Bytes selected for one import; origin identifies the original without becoming a destination.
class ImportInput {
  const ImportInput({
    required this.name,
    required this.origin,
    required this.bytes,
  });
  final String name, origin;
  final List<int> bytes;
}

/// User-mediated file selection, separate from format parsing and database writes.
abstract interface class DocumentAccess {
  /// Whether the current platform exposes user-selected directory import.
  bool get supportsDirectories;

  /// An empty result represents a dismissed picker, not an import error.
  Future<List<ImportInput>> pickFiles();

  /// Recursively selects supported materials while enforcing read-size limits.
  Future<List<ImportInput>> pickDirectory();
}

/// Readable text with a page/section label suitable for source attribution.
class ParsedSection {
  const ParsedSection(this.location, this.text);
  final String location, text;
}

/// Extracts text only; it must not publish documents, questions or guidance itself.
abstract interface class DocumentParser {
  /// Format dispatch only; a supported extension does not guarantee readable contents.
  bool supports(String filename);

  /// Extracts attributed sections or throws a readable failure (for example missing OCR).
  Future<List<ParsedSection>> parse(ImportInput input);
}

/// Expands a selected archive into a bounded, temporary stream of materials.
abstract interface class ArchiveAccess {
  /// Yields bounded temporary inputs; cancellation must release extraction resources.
  Stream<ImportInput> pickZip();
}
