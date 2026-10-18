import '../../domain/models.dart';

abstract interface class MaterialRepository {
  Future<List<StudyDocument>> documents();
  Future<StudyDocument?> byOrigin(String origin);
  Future<void> importDocument(StudyDocument document, List<SourceChunk> chunks);
  Future<void> removeDocument(String id);
  Future<List<SourceChunk>> chunks(String? documentId);
}

abstract interface class QuestionRepository {
  Future<List<Question>> ready(String? scope);
  Future<List<String>> recentPrompts(String? scope);
  Future<List<ReviewEntry>> reviews();
  Future<void> flagQuestion(String id);
  Future<StudyStats> stats();
}

abstract interface class ProgressRepository {
  Future<void> submit(AnswerAttempt attempt);
}

abstract interface class ProfileRepository {
  Future<ProviderProfile?> load();
  Future<void> save(ProviderProfile profile);
}

abstract interface class CredentialStore {
  Future<String?> read(String reference);
  Future<void> write(String reference, String secret);
  Future<void> delete(String reference);
}

abstract interface class JobRepository {
  Future<int> epoch();
  Future<void> recover();
  Future<void> enqueue(GenerationJob job);
  Future<bool> claim(String id, DateTime now);
  Future<bool> complete(GenerationJob job, List<Question> questions);
  Future<void> fail(String id, String message, {bool cancelled = false});
  Future<void> retry(String id, DateTime at);
}

abstract interface class AiQuestionGenerator {
  Future<List<Question>> generate(GenerationRequest request);
  Future<void> probe(ProviderProfile profile, String apiKey);
  void cancel();
}

class ImportInput {
  const ImportInput({
    required this.name,
    required this.origin,
    required this.bytes,
  });
  final String name, origin;
  final List<int> bytes;
}

abstract interface class DocumentAccess {
  bool get supportsDirectories;
  Future<List<ImportInput>> pickFiles();
  Future<List<ImportInput>> pickDirectory();
}

class ParsedSection {
  const ParsedSection(this.location, this.text);
  final String location, text;
}

abstract interface class DocumentParser {
  bool supports(String filename);
  Future<List<ParsedSection>> parse(ImportInput input);
}
