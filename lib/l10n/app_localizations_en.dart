// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get library => 'Library';

  @override
  String get practice => 'Practice';

  @override
  String get review => 'Review';

  @override
  String get settings => 'Settings';

  @override
  String get tagline => 'Make knowledge yours.';

  @override
  String get localByDesign => 'Local by design';

  @override
  String get libraryEyebrow => 'Your learning space';

  @override
  String get libraryTitle => 'A little practice. A lot of progress.';

  @override
  String get librarySubtitle =>
      'Bring your notes. Build understanding, one question at a time.';

  @override
  String get documents => 'Documents';

  @override
  String get questionsReady => 'Questions ready';

  @override
  String get answersGiven => 'Answers given';

  @override
  String get toRevisit => 'To revisit';

  @override
  String get importFiles => 'Import files';

  @override
  String get importFolder => 'Import folder';

  @override
  String get goToPractice => 'Go to practice';

  @override
  String get supportedFiles =>
      'TXT, Markdown & text PDF · up to 20 MB per file';

  @override
  String get libraryEmptyTitle => 'Your next chapter starts here';

  @override
  String get libraryEmptyBody =>
      'Import a document to turn it into practice questions.\nYour materials stay on this device until you choose to generate.';

  @override
  String get trySample => 'Try sample notes';

  @override
  String get close => 'Close';

  @override
  String get removeDocument => 'Remove document';

  @override
  String get removeDocumentTitle => 'Remove this document?';

  @override
  String get removeDocumentBody =>
      'Its questions will leave the practice and review queues. Your answer history will be retained.';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get reviewPracticeEyebrow => 'Build lasting knowledge';

  @override
  String get practiceEyebrow => 'One question at a time';

  @override
  String get reviewPracticeTitle => 'A second look.';

  @override
  String get practiceTitle => 'Find your flow.';

  @override
  String get reviewPracticeSubtitle =>
      'Recall it first. Then read the explanation.';

  @override
  String get practiceSubtitle =>
      'Fresh questions from your materials, ready before you need them.';

  @override
  String get practiceScope => 'Practice scope';

  @override
  String get allMaterials => 'All materials';

  @override
  String get pauseGeneration => 'Pause generation';

  @override
  String get generateTitle => 'Generate practice questions?';

  @override
  String get generateBody =>
      'Relevant excerpts will be sent to your configured AI provider. Generation uses your API balance and automatically replenishes a buffer of up to 20 questions while practice is active. You can pause at any time.';

  @override
  String get start => 'Start';

  @override
  String get generateQuestions => 'Generate questions';

  @override
  String get backToFresh => 'Back to fresh questions';

  @override
  String get reviewCaughtUp => 'You’re caught up for now';

  @override
  String get firstQuestion => 'Ready for your first question?';

  @override
  String get reviewCaughtUpBody =>
      'Come back when your next review is due, or choose another item from Review.';

  @override
  String get firstQuestionBody =>
      'Import your notes, connect an AI provider, then start generating.\nOnce saved, questions work offline too.';

  @override
  String get openLibrary => 'Open library';

  @override
  String get reviewQueue => 'Review queue';

  @override
  String get setUpAi => 'Set up AI';

  @override
  String get singleChoice => 'Single choice';

  @override
  String get saving => 'Saving…';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get checkAnswer => 'Check answer';

  @override
  String get hideQuestionTitle => 'Hide this question?';

  @override
  String get hideQuestionBody =>
      'If the question is incorrect or ambiguous, remove it from practice and review. This report stays on your device.';

  @override
  String get hideQuestion => 'Hide question';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get correctAnswer => 'Well done.';

  @override
  String get wrongAnswer => 'A useful mistake.';

  @override
  String get fullSource => 'Read the full source excerpt';

  @override
  String get aiDisclaimer =>
      'AI-generated. Check the source if an answer seems wrong.';

  @override
  String get reviewEyebrow => 'Mistakes become progress';

  @override
  String get reviewTitle => 'Worth another look.';

  @override
  String get reviewSubtitle =>
      'Missed questions return here. Three correct reviews graduate a question from this queue.';

  @override
  String get reviewEmptyTitle => 'A fresh start';

  @override
  String get reviewEmptyBody =>
      'Your missed questions will appear here. Keep practicing to discover what needs another look.';

  @override
  String get dueNow => 'Due now';

  @override
  String get reviewEarly => 'Review early';

  @override
  String get reviewNow => 'Review now';

  @override
  String get settingsEyebrow => 'Make it yours';

  @override
  String get settingsTitle => 'Your AI. Your choice.';

  @override
  String get settingsSubtitle =>
      'Connect an OpenAI-compatible Chat Completions API. No OmniQuiz account or server.';

  @override
  String get aiProvider => 'AI provider';

  @override
  String get apiBaseUrl => 'API base URL';

  @override
  String get apiBaseUrlHelp =>
      'Include /v1 if your provider requires it. Do not append /chat/completions.';

  @override
  String get modelId => 'Model ID';

  @override
  String get modelHint => 'Enter a model available from your provider';

  @override
  String get apiKey => 'API key';

  @override
  String get pasteKey => 'Paste your API key';

  @override
  String get keepKey => 'Leave blank to keep the saved key';

  @override
  String get hideKey => 'Hide key';

  @override
  String get showKey => 'Show key';

  @override
  String get noKey => 'This endpoint does not require a key';

  @override
  String get jsonMode => 'JSON response mode';

  @override
  String get jsonModeHelp =>
      'Enable only if your provider supports response_format: json_object.';

  @override
  String get questionLanguage => 'Question language';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get testConnection => 'Test connection';

  @override
  String get privacyNotice =>
      'Generation sends selected source excerpts to your chosen provider. Connection tests make a small paid API request. Keys are kept in system secure storage; documents and study progress stay local.';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get appLanguage => 'Interface language';

  @override
  String get systemLanguage => 'Follow system';

  @override
  String get appLanguageHelp =>
      'Applies immediately and is saved on this device. Question language is configured separately below.';

  @override
  String get questionLanguageHelp =>
      'Applies to newly generated questions and explanations. Existing questions keep their original language.';

  @override
  String get languageSaveError =>
      'Could not save the interface language. Please try again.';

  @override
  String get startupError =>
      'OmniQuiz could not open local storage. Check available disk space and application permissions, then restart.';

  @override
  String readyCount(int count) {
    return '$count ready';
  }

  @override
  String documentDetails(int count, String date) {
    return '$count source excerpts · imported $date';
  }

  @override
  String reviewProgress(int streak, int mistakes) {
    return '$streak/3 correct reviews · $mistakes missed';
  }

  @override
  String dueDate(String date) {
    return 'Due $date';
  }

  @override
  String sourceName(String name) {
    return 'SOURCE · $name';
  }

  @override
  String importSummary(int count, int unchanged) {
    return '$count imported · $unchanged unchanged';
  }

  @override
  String bufferReady(int count) {
    return '$count questions ready';
  }

  @override
  String retryGeneration(int attempt) {
    return 'Retrying generation ($attempt/3)…';
  }

  @override
  String httpError(int code) {
    return 'Provider returned HTTP $code. Check the base URL, model and JSON mode.';
  }

  @override
  String fileTooLarge(String name) {
    return '$name exceeds the 20 MB file limit.';
  }

  @override
  String textLocation(String start, String end) {
    return 'Text · characters $start–$end';
  }

  @override
  String pageLocation(String page, String start, String end) {
    return 'Page $page · characters $start–$end';
  }

  @override
  String get invalidQuestion => 'The provider returned an invalid question.';

  @override
  String get invalidProfile =>
      'Enter an HTTPS API base URL and a model name. HTTP is allowed only for localhost.';

  @override
  String get loadLibraryError => 'Could not load your library.';

  @override
  String get importError =>
      'Import failed. Check file permissions and try again.';

  @override
  String get removeError => 'Could not remove this document.';

  @override
  String get loadQuestionsError => 'Could not load questions.';

  @override
  String get saveAnswerError => 'Could not save your answer. Try again.';

  @override
  String get loadReviewError => 'Could not load your review queue.';

  @override
  String get loadSettingsError => 'Could not load provider settings.';

  @override
  String get settingsSaved =>
      'Settings saved. Your key is stored securely on this device.';

  @override
  String get saveSettingsError => 'Could not save settings.';

  @override
  String get testKeyRequired =>
      'Enter the API key for this endpoint before testing.';

  @override
  String get connectionSuccess =>
      'Connection successful. The model returned valid JSON.';

  @override
  String get connectionError =>
      'Connection test failed. Check secure storage and connectivity.';

  @override
  String get readyStatus => 'Ready when you are';

  @override
  String get pausedStatus =>
      'Generation paused · cached questions remain available';

  @override
  String get configureFirst => 'Configure your AI provider in Settings first.';

  @override
  String get importFirst => 'Import study materials first.';

  @override
  String get generatingStatus => 'Preparing your next questions…';

  @override
  String get changedStatus =>
      'Materials or settings changed. Start generation again.';

  @override
  String get savedQuestionsStatus => 'New questions saved';

  @override
  String get generateError =>
      'Could not save or generate questions. Please try again.';

  @override
  String get fileLimit => 'File exceeds 20 MB.';

  @override
  String get textLimit =>
      'Extracted text exceeds 1 million characters. Split the file.';

  @override
  String get noText => 'No readable text found.';

  @override
  String get readError => 'Could not read this file.';

  @override
  String get keyRequired =>
      'Enter an API key or explicitly select an endpoint without a key.';

  @override
  String get newKeyRequired =>
      'Enter a key for the new endpoint, or explicitly select no key.';

  @override
  String get secureSaveError =>
      'Secure storage is unavailable. API key was not saved.';

  @override
  String get encodingError => 'Text files must use UTF-8 encoding.';

  @override
  String get documentLimit =>
      'This document is too large. Split it into smaller files.';

  @override
  String get scanError => 'No text found. Scanned PDFs need OCR before import.';

  @override
  String get formatError =>
      'Supported formats: TXT, Markdown, and text-based PDF.';

  @override
  String get authError =>
      'API authorization failed. Check your key and model access.';

  @override
  String get quotaError =>
      'Provider rate limit or quota reached. Try again later.';

  @override
  String get providerUnavailable =>
      'The AI provider is temporarily unavailable.';

  @override
  String get responseLimit => 'Provider response exceeded the size limit.';

  @override
  String get outputTruncated =>
      'Provider output was truncated. Try a model with a larger output limit.';

  @override
  String get timeoutError =>
      'Generation timed out. A retry may incur another API charge.';

  @override
  String get invalidJson => 'The provider returned invalid JSON.';

  @override
  String get incompatibleResponse =>
      'The provider response is not compatible with Chat Completions.';

  @override
  String get networkError =>
      'Could not reach the provider. Check your connection and API address.';

  @override
  String get probeJsonError =>
      'The model responded, but did not follow the JSON test. Try another model.';

  @override
  String get modelJsonError =>
      'The model did not return valid JSON. Try JSON mode or a different model.';

  @override
  String get secureReadError =>
      'Cannot access secure storage. Unlock your device and try again.';

  @override
  String get missingCredentials =>
      'API credentials are missing. Save them in Settings.';

  @override
  String get noQuestions => 'The provider returned no question list.';

  @override
  String get staleQuestion =>
      'This question is no longer available. Choose another question.';

  @override
  String get invalidAnswer => 'Invalid answer submission.';

  @override
  String get noNewQuestions =>
      'No new valid questions were generated. Try another source or model.';

  @override
  String get invalidBatch =>
      'No valid, new questions were returned. Try another model or add more material.';

  @override
  String get fileReadError =>
      'The selected file could not be read. Try copying it to this device first.';

  @override
  String get useFiles => 'Use Import files on this device.';

  @override
  String get folderLimit =>
      'Import at most 100 files / 100 MB at once. Select a smaller folder.';

  @override
  String get currentLibrary => 'Current library';

  @override
  String get createLibrary => 'Create library';

  @override
  String get libraryName => 'Library name';

  @override
  String get useExistingFolder => 'Use an existing folder';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get folderIncludesSubfolders =>
      'Choose a folder, including its subfolders.';

  @override
  String get managedFolderDescription =>
      'Create an app-managed folder. Imported files will be copied there.';

  @override
  String get mobileLibraryDescription =>
      'This device uses app-managed folders. Add materials with Import files.';

  @override
  String get libraryNameRequired => 'Enter a name and choose a folder.';

  @override
  String get createLibraryError =>
      'Could not create library. Check folder access and use non-overlapping folders.';

  @override
  String get create => 'Create';

  @override
  String get scanFolder => 'Scan folder';

  @override
  String get libraryIsolationDescription =>
      'Questions, mistakes and progress belong to this library. Folders scan on launch, switch and resume; scan manually anytime.';

  @override
  String get openLibraryError => 'Could not open this library. Try again.';

  @override
  String get scanFolderError =>
      'Could not scan the library folder. Check that it is connected and grant folder access again.';

  @override
  String get folderUnavailable =>
      'Library folder is unavailable. Reconnect it and scan again.';

  @override
  String get copyLibraryFileError =>
      'Cannot copy this file into the library folder.';

  @override
  String get grantFolderAccess => 'Grant folder access';

  @override
  String get grantFolderError =>
      'Choose the same library folder to restore access.';

  @override
  String get removeIndexedDocumentBody =>
      'This removes the document and its questions from practice, but keeps the original file. Scanning the folder will import it again. To exclude it permanently, move the file out of this folder.';
}
