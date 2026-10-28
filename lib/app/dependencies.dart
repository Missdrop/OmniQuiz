// Builds one library session while sharing only global account and interface preferences.

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../application/generation/coordinator.dart';
import '../application/libraries/library_files.dart';
import '../application/libraries/library_scanner.dart';
import '../infrastructure/persistence/scan_state_store.dart';
import '../application/generation/question_validator.dart';
import '../application/ports/repositories.dart';
import '../application/use_cases/configure_provider.dart';
import '../application/use_cases/import_materials.dart';
import '../domain/policies.dart';
import '../infrastructure/ai/chat_completions_generator.dart';
import '../infrastructure/ai/compatible_model_catalog.dart';
import '../infrastructure/ai/chatgpt_sessions.dart';
import '../infrastructure/ai/chatgpt_responses.dart';
import '../application/ports/model_catalog.dart';
import '../infrastructure/documents/parsers.dart';
import '../infrastructure/persistence/database.dart';
import '../infrastructure/persistence/repositories.dart';
import '../infrastructure/platform/credentials.dart';
import '../infrastructure/platform/document_access.dart';
import '../infrastructure/platform/zip_document_access.dart';
import '../presentation/library/library_view_model.dart';
import '../presentation/practice/practice_view_model.dart';
import '../presentation/review/review_view_model.dart';
import '../presentation/settings/settings_view_model.dart';
import '../presentation/settings/language_view_model.dart';
import '../presentation/settings/appearance_view_model.dart';
import '../presentation/settings/question_language_view_model.dart';
import '../infrastructure/persistence/preferences_repository.dart';
import '../infrastructure/persistence/generation_guidance_repository.dart';
import '../presentation/practice/guidance_view_model.dart';
import '../infrastructure/persistence/file_guidance_repository.dart';
import '../infrastructure/persistence/library_workspace.dart';
import '../infrastructure/persistence/generation_log.dart';
import '../infrastructure/persistence/connection_repository.dart';
import '../infrastructure/persistence/selected_connection_profile.dart';

/// Owns a disposable library dependency graph; global settings may use a separate database.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.coordinator,
    required this.library,
    required this.practice,
    required this.review,
    required this.settings,
    required this.language,
    required this.appearance,
    required this.questionLanguage,
    required this.guidance,
    required this.ownsDatabase,
    this.generationLog,
  });
  final QuizDatabase database;
  final bool ownsDatabase;
  final GenerationCoordinator coordinator;
  final LibraryViewModel library;
  final PracticeViewModel practice;
  final ReviewViewModel review;
  final SettingsViewModel settings;
  final LanguageViewModel language;
  final AppearanceViewModel appearance;
  final QuestionLanguageViewModel questionLanguage;
  final GuidanceViewModel guidance;
  final GenerationLog? generationLog;

  static Future<AppDependencies> create({
    required QuizDatabase database,
    QuizDatabase? settingsDatabase,
    bool ownsDatabase = true,
    LibraryFiles? libraryFiles,
    DocumentAccess? documentAccess,
    ArchiveAccess? archiveAccess,
    CredentialStore? credentialStore,
    AiQuestionGenerator? ai,
    ModelCatalog? modelCatalog,
    BufferPolicy bufferPolicy = const BufferPolicy(),
  }) async {
    final materials = SqlMaterialRepository(database);
    final language = LanguageViewModel(
      SqlPreferencesRepository(settingsDatabase ?? database),
    );
    await language.load();
    final appearance = AppearanceViewModel(
      SqlPreferencesRepository(settingsDatabase ?? database),
    );
    await appearance.load();
    final questionLanguage = QuestionLanguageViewModel(
      SqlPreferencesRepository(settingsDatabase ?? database),
    );
    await questionLanguage.load();
    final questions = SqlQuestionRepository(database);
    final parser = ParserRegistry([TextDocumentParser(), PdfDocumentParser()]);
    final GenerationGuidanceRepository guidanceRepository = libraryFiles == null
        ? SqlGenerationGuidanceRepository(database)
        : FileGenerationGuidanceRepository(
            LibraryWorkspace(libraryFiles.directory),
            SqlGenerationGuidanceRepository(database),
            parser,
          );
    final connectionRepository = SqlConnectionRepository(
      settingsDatabase ?? database,
    );
    final profiles = SelectedConnectionProfile(connectionRepository);
    final credentials =
        credentialStore ??
        PlatformCredentialStore(
          FlutterSecureStorage(
            mOptions: MacOsOptions(
              usesDataProtectionKeychain: !Platform.isMacOS,
            ),
          ),
        );
    const ids = UuidGenerator();
    final clock = SystemClock();
    final jobs = SqlJobRepository(database, clock);
    await jobs.recover();
    final chatGpt = ChatGptSessions(credentials);
    late final GenerationCoordinator coordinator;
    final journal = libraryFiles == null
        ? null
        : GenerationLog(LibraryWorkspace(libraryFiles.directory));
    final generator =
        ai ??
        ChatCompletionsGenerator(
          credentials,
          QuestionValidator(ids),
          chatGpt: ChatGptResponses(chatGpt),
          onProgress: (message) => coordinator.reportProgress(message),
        );
    coordinator = GenerationCoordinator(
      materials: materials,
      questions: questions,
      profiles: profiles,
      jobs: jobs,
      generator: generator,
      ids: ids,
      clock: clock,
      questionLanguage: () => questionLanguage.resolved,
      guidance: guidanceRepository,
      onStatus: journal?.record,
      policy: bufferPolicy,
    );
    final access = documentAccess ?? PlatformDocumentAccess();
    final practice = PracticeViewModel(
      questions,
      SqlProgressRepository(database, const ReviewPolicy()),
      coordinator,
      ids,
      clock,
    );
    final guidance = GuidanceViewModel(
      guidanceRepository,
      access,
      parser,
      practice.applyGuidanceChange,
    );
    await guidance.load();
    final importer = ImportMaterials(materials, parser, ids, clock);
    return AppDependencies._(
      database: database,
      coordinator: coordinator,
      library: LibraryViewModel(
        materials,
        questions,
        access,
        importer,
        coordinator,
        files: libraryFiles,
        scanner: libraryFiles == null
            ? null
            : LibraryScanner(
                libraryFiles,
                materials,
                importer,
                SqlScanStateStore(database),
              ),
        archives: archiveAccess ?? ZipDocumentAccess(),
      ),
      practice: practice,
      review: ReviewViewModel(questions),
      settings: SettingsViewModel(
        profiles,
        credentials,
        ConfigureProvider(profiles, credentials, ids),
        generator,
        coordinator,
        catalog: modelCatalog ?? CompatibleModelCatalog(),
        chatGpt: chatGpt,
        questionLanguage: () => questionLanguage.resolved,
        connectionRepository: connectionRepository,
        applyConnectionChange: practice.applyGuidanceChange,
        endPractice: practice.endPractice,
      ),
      language: language,
      appearance: appearance,
      questionLanguage: questionLanguage,
      guidance: guidance,
      ownsDatabase: ownsDatabase,
      generationLog: journal,
    );
  }

  Future<void>? _disposeFuture;

  /// Shutdown is idempotent because both host disposal and library switches can race.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    await library.stopScan();
    practice.dispose();
    await coordinator.dispose();
    await generationLog?.flush();
    library.dispose();
    review.dispose();
    settings.dispose();
    language.dispose();
    appearance.dispose();
    questionLanguage.dispose();
    guidance.dispose();
    if (ownsDatabase) await database.close();
  }
}
