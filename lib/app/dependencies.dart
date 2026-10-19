import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../application/generation/coordinator.dart';
import '../application/libraries/library_files.dart';
import '../application/generation/question_validator.dart';
import '../application/ports/repositories.dart';
import '../application/use_cases/configure_provider.dart';
import '../application/use_cases/import_materials.dart';
import '../domain/policies.dart';
import '../infrastructure/ai/chat_completions_generator.dart';
import '../infrastructure/documents/parsers.dart';
import '../infrastructure/persistence/database.dart';
import '../infrastructure/persistence/repositories.dart';
import '../infrastructure/platform/credentials.dart';
import '../infrastructure/platform/document_access.dart';
import '../presentation/library/library_view_model.dart';
import '../presentation/practice/practice_view_model.dart';
import '../presentation/review/review_view_model.dart';
import '../presentation/settings/settings_view_model.dart';
import '../presentation/settings/language_view_model.dart';
import '../infrastructure/persistence/preferences_repository.dart';

class AppDependencies {
  AppDependencies._(
    this.database,
    this.coordinator,
    this.library,
    this.practice,
    this.review,
    this.settings,
    this.language,
    this.ownsDatabase,
  );
  final QuizDatabase database;
  final bool ownsDatabase;
  final GenerationCoordinator coordinator;
  final LibraryViewModel library;
  final PracticeViewModel practice;
  final ReviewViewModel review;
  final SettingsViewModel settings;
  final LanguageViewModel language;

  static Future<AppDependencies> create({
    required QuizDatabase database,
    QuizDatabase? settingsDatabase,
    bool ownsDatabase = true,
    LibraryFiles? libraryFiles,
    DocumentAccess? documentAccess,
    CredentialStore? credentialStore,
    AiQuestionGenerator? ai,
  }) async {
    final materials = SqlMaterialRepository(database);
    final language = LanguageViewModel(
      SqlPreferencesRepository(settingsDatabase ?? database),
    );
    await language.load();
    final questions = SqlQuestionRepository(database);
    final profiles = SqlProfileRepository(settingsDatabase ?? database);
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
    final generator =
        ai ?? ChatCompletionsGenerator(credentials, QuestionValidator(ids));
    final coordinator = GenerationCoordinator(
      materials: materials,
      questions: questions,
      profiles: profiles,
      jobs: jobs,
      generator: generator,
      ids: ids,
      clock: clock,
    );
    return AppDependencies._(
      database,
      coordinator,
      LibraryViewModel(
        materials,
        questions,
        documentAccess ?? PlatformDocumentAccess(),
        ImportMaterials(
          materials,
          ParserRegistry([TextDocumentParser(), PdfDocumentParser()]),
          ids,
          clock,
        ),
        coordinator,
        files: libraryFiles,
      ),
      PracticeViewModel(
        questions,
        SqlProgressRepository(database, const ReviewPolicy()),
        coordinator,
        ids,
        clock,
      ),
      ReviewViewModel(questions),
      SettingsViewModel(
        profiles,
        credentials,
        ConfigureProvider(profiles, credentials, ids),
        generator,
        coordinator,
      ),
      language,
      ownsDatabase,
    );
  }

  Future<void>? _disposeFuture;
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    practice.dispose();
    await coordinator.dispose();
    library.dispose();
    review.dispose();
    settings.dispose();
    language.dispose();
    if (ownsDatabase) await database.close();
  }
}
