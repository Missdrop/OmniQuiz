// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'OmniQuiz';

  @override
  String get manageMaterials => 'Manage materials';

  @override
  String get materialSelectionHelp =>
      'Selected materials are used for new questions. New files are selected automatically. Deselecting keeps files, questions and answer history.';

  @override
  String get backToLibrary => 'Back to library';

  @override
  String materialsSelected(int count) {
    return '$count selected';
  }

  @override
  String materialSelectionCount(int selected, int total) {
    return '$selected selected / $total materials';
  }

  @override
  String get selectAllMaterials => 'Select all';

  @override
  String get deselectAllMaterials => 'Deselect all';

  @override
  String get viewMaterial => 'View material';

  @override
  String get materialSelectionError =>
      'Could not save material selection. Please try again.';

  @override
  String get answerHistory => 'Answer history';

  @override
  String get answerHistoryHelp =>
      'Review answers, explanations and sources from practice and review sessions.';

  @override
  String get answerHistoryEmpty => 'No answers yet';

  @override
  String get answerHistoryEmptyHelp =>
      'Complete a question to see your answer here.';

  @override
  String get historyCorrect => 'Correct';

  @override
  String get historyIncorrect => 'Incorrect';

  @override
  String get historyYourAnswer => 'Your choice';

  @override
  String get historyRightAnswer => 'Correct answer';

  @override
  String get historyExplanation => 'Explanation';

  @override
  String get historyLoadError =>
      'Could not load answer history. Please try again.';

  @override
  String get retryHistory => 'Retry';

  @override
  String get loadMoreHistory => 'Load more answers';

  @override
  String get deleteLibrary => 'Delete library';

  @override
  String deleteLibraryTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteLibraryBody =>
      'This removes the library from the list and deletes its questions, mistakes and generation settings. This cannot be undone. Consider making a backup first.';

  @override
  String get keepLibraryMaterials => 'Keep material files';

  @override
  String get deleteLibraryKeepHelp =>
      'Keep original PDFs, documents and other materials. Only .omniquiz study data is deleted.';

  @override
  String get deleteLibraryFolderWarning =>
      'The entire folder shown above and every file inside it will be permanently deleted.';

  @override
  String get deleteLibraryError =>
      'Could not delete the library. Check folder access. System folders and folders containing other libraries cannot be deleted as a whole.';

  @override
  String get deleteLibraryCleanupError =>
      'The library was removed, but some local study data could not be deleted. Check folder access.';

  @override
  String get guidanceTitle => 'Question settings';

  @override
  String get guidanceHelp =>
      'Set the pace, examples and requirements for this library. Examples guide style; answers come from your materials. Requirements and sample excerpts are sent to your selected AI during generation.';

  @override
  String get extraRequirements => 'Additional question requirements';

  @override
  String get extraRequirementsHint =>
      'For example: medium difficulty; focus on applying concepts, use plausible distractors, and explain why other options are incorrect.';

  @override
  String get pasteExamples => 'Paste sample questions or paper text (optional)';

  @override
  String get importExamples => 'Import sample questions / papers';

  @override
  String get guidanceFormats =>
      'TXT, Markdown and text-based PDF; up to 8 files, 20 MB each. Scanned papers need OCR first.';

  @override
  String exampleCharacters(int count) {
    return '$count characters · Expand to preview';
  }

  @override
  String get removeExample => 'Remove example';

  @override
  String get replaceGuidanceBuffer => 'Regenerate unanswered questions';

  @override
  String get replaceGuidanceBufferHelp =>
      'Keeps answer history and reviews. Active practice continues with the new requirements and uses service allowance. When unchecked, existing cached questions stay unchanged and guidance applies only to future generation.';

  @override
  String get saveGuidance => 'Save question settings';

  @override
  String get guidanceEnabled =>
      'This library\'s examples / question requirements are enabled';

  @override
  String get guidanceLimitError =>
      'Size or count limit exceeded. Shorten requirements, split papers or remove examples.';

  @override
  String get guidanceLoadError =>
      'Could not load question settings. Save them again to repair them.';

  @override
  String get guidanceImportError =>
      'Could not import samples. Check their format and readable text.';

  @override
  String get guidanceSaveError =>
      'Question settings were not saved. Please try again.';

  @override
  String get guidanceInvalidExamples =>
      'Invalid or duplicate examples. Please import them again.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyLoadFailed =>
      'Could not load the privacy policy. Please reopen this page.';

  @override
  String get reportToDeveloper => 'Report AI content to developer';

  @override
  String get storeUpdatesHelp =>
      'This edition is distributed and updated by Microsoft Store. Use the Store to check for and install updates.';

  @override
  String get openMicrosoftStore => 'Open Microsoft Store';

  @override
  String get gatewayTitle =>
      'Use ChatGPT or other accounts through CLIProxyAPI';

  @override
  String get gatewayHelp =>
      'Sign in to your provider in your own CLIProxyAPI gateway first. Enter its OpenAI-compatible base URL and client API key below, load the available models, then test and save. Use the gateway client key, not a ChatGPT password, OAuth token, or gateway management key. Model access and usage limits depend on the connected account. The gateway receives the study excerpts you send for generation.';

  @override
  String get gatewayAddressHelp =>
      'On this computer: http://127.0.0.1:8317/v1\nOn a phone: your gateway\'s reachable HTTPS address ending in /v1. A phone\'s localhost refers to the phone, not your computer. Keep the gateway running. For standalone use, choose ChatGPT sign-in above.';

  @override
  String get loadModels => 'Load available models';

  @override
  String get chooseModel => 'Choose a model';

  @override
  String get searchModels => 'Search models';

  @override
  String get loadModelsError =>
      'Could not load models. Check the endpoint and key, or enter a model manually.';

  @override
  String get noModelsError =>
      'No models are available. Sign in to a provider on your gateway, or enter a model manually.';

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
  String get appearance => 'Appearance';

  @override
  String get systemTheme => 'Follow system';

  @override
  String get lightTheme => 'Light mode';

  @override
  String get darkTheme => 'Dark mode';

  @override
  String get switchToLight => 'Switch to light mode';

  @override
  String get switchToDark => 'Switch to dark mode';

  @override
  String get themeSaveError =>
      'Could not save appearance settings. Please retry.';

  @override
  String get startPractice => 'Start practice';

  @override
  String get endPractice => 'End practice';

  @override
  String get retryPractice => 'Retry refill';

  @override
  String get practiceSessionHelp =>
      'Starting practice automatically refills questions as you run low. Leaving this page or ending practice stops requests. New questions require an internet connection and use your selected service allowance.';

  @override
  String get practiceAutoReady =>
      'Practice is active. More questions will be prepared as you run low.';

  @override
  String get waitingForQuestion => 'Preparing your next question…';

  @override
  String get waitingForQuestionBody =>
      'Your next question will appear automatically. You do not need to start again. If the connection fails, check the message above.';

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
      'Stop generating new questions from this material. Existing questions, mistakes, answer history and the original file are kept.';

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
      'Start once and keep practicing. Questions refill automatically from your materials.';

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
      'Relevant excerpts will be sent to your selected AI connection and consume its plan allowance or API usage. Questions refill automatically up to 20 while practicing. You can pause at any time.';

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
      'Import your notes, connect an AI provider, then select Start practice.\nQuestions refill while you practice. Saved questions also work offline.';

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
      'Hide an incorrect or inappropriate question locally. To ask the developer to address it, choose Report AI content to developer and fill out and submit the GitHub form. Reports are public: do not include private materials or credentials. Question content is not attached automatically.';

  @override
  String get hideQuestion => 'Hide question';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get correctAnswer => 'Well done.';

  @override
  String get wrongAnswer => 'A useful mistake.';

  @override
  String get fullSource => 'View original source';

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
      'Use your ChatGPT plan or an OpenAI-compatible API. No OmniQuiz account or server required.';

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
      'Generation sends selected excerpts to your AI connection. Connection tests use a small amount of plan allowance or API usage. Credentials stay in OS secure storage; materials and progress stay local.';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get appLanguage => 'Interface language';

  @override
  String get systemLanguage => 'Follow system';

  @override
  String get appLanguageHelp =>
      'Applies immediately and is saved on this device.';

  @override
  String get questionLanguageHelp =>
      'Shared by all AI connections. New questions and explanations follow the system language by default; existing questions stay unchanged.';

  @override
  String get noLibrariesTitle => 'Create your first library';

  @override
  String get noLibrariesBody =>
      'No libraries yet. Create one before importing your learning materials.';

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
  String get openLibraryError =>
      'Could not open this library. Reconnect its folder or grant folder access, then reopen it.';

  @override
  String get reopenLibrary => 'Reopen library';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

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
      'This removes the imported document from practice and excludes its file from future scans. The original file is kept. Use Excluded files to import it again.';

  @override
  String get importZip => 'Import ZIP';

  @override
  String get zipSupportedFiles =>
      'TXT, Markdown & text PDF · 20 MB per file · ZIP: 100 MB compressed / extracted, up to 1000 entries';

  @override
  String get zipReadError =>
      'Could not read this ZIP. Use an unencrypted ZIP with standard compression.';

  @override
  String get zipSelectedReadError => 'The selected ZIP could not be read.';

  @override
  String get zipArchiveLimit => 'ZIP exceeds the 100 MB archive limit.';

  @override
  String get zipEntryLimit =>
      'ZIP contains more than 1000 entries. Split the archive.';

  @override
  String get zipUnsafePaths =>
      'ZIP contains unsafe paths or links. Nothing was imported.';

  @override
  String get zipInvalidSizes => 'ZIP contains invalid file sizes.';

  @override
  String get zipExpandedLimit => 'ZIP expands beyond the 100 MB limit.';

  @override
  String get zipDuplicatePaths =>
      'ZIP contains unsafe or duplicate file paths.';

  @override
  String get zipMaterialLimit =>
      'A material in the ZIP exceeds the 20 MB file limit.';

  @override
  String get zipNoMaterials =>
      'No supported materials in ZIP. Include TXT, Markdown or text PDF.';

  @override
  String get zipDamaged => 'ZIP is damaged. Nothing was imported.';

  @override
  String get zipImportError =>
      'Could not import ZIP. Check storage space and file permissions.';

  @override
  String get backupTitle => 'Back up your libraries';

  @override
  String get backupHelp =>
      'Save all libraries, materials, questions and progress. AI settings and API keys are excluded. Backups contain your private study data.';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get restoreBackupHelp =>
      'Restore a previously exported OmniQuiz backup as new libraries. Your existing libraries and AI settings will be kept.';

  @override
  String get backupSaved => 'Backup saved.';

  @override
  String get backupFailed =>
      'Backup failed. Check storage space and folder access.';

  @override
  String backupRestored(int count) {
    return 'Restored $count libraries. Switch libraries to open them.';
  }

  @override
  String backupMissingOriginals(int count) {
    return 'Backup saved. $count original files were unavailable; their extracted text and learning records were preserved.';
  }

  @override
  String get backupTooLarge => 'Backup is too large.';

  @override
  String get backupSourceError => 'A source file could not be backed up.';

  @override
  String get backupReadError => 'Backup could not be read.';

  @override
  String get backupRestoreError =>
      'Backup is invalid or could not be restored. Your existing libraries were kept.';

  @override
  String get maintenanceBusy =>
      'Finish the current operation before backing up or restoring.';

  @override
  String get fullScan => 'Verify all files';

  @override
  String get cancelScan => 'Stop scanning';

  @override
  String get scanCancelled => 'Scan cancelled. Completed imports were kept.';

  @override
  String get sourceMissing =>
      'Source file unavailable; imported content and progress are retained.';

  @override
  String get restoreImport => 'Import again';

  @override
  String get restoreExcludedError => 'Could not restore this excluded file.';

  @override
  String excludedFiles(int count) {
    return 'Excluded files ($count)';
  }

  @override
  String scanProgress(int count, String name) {
    return 'Checked $count files · $name';
  }

  @override
  String scanSourceSummary(int excluded, int missing) {
    return '$excluded excluded · $missing missing sources';
  }

  @override
  String get chatGptTitle => 'ChatGPT subscription';

  @override
  String get chatGptHelp =>
      'Sign in on this device using your eligible ChatGPT plan. No API key, computer, or gateway is needed. Complete authorization in the browser, then return here.';

  @override
  String get chatGptActive => 'Selected for generation';

  @override
  String get chatGptAccount => 'ChatGPT account';

  @override
  String get continueChatGpt => 'Continue with ChatGPT';

  @override
  String get chatGptAddAccount => 'Add another account';

  @override
  String get chatGptSignOut => 'Sign out';

  @override
  String get chatGptUseModel => 'Test and use this model';

  @override
  String get chatGptTestHelp =>
      'Signing in saves your account and selects the first available model automatically. Model and question-language changes are saved immediately. Testing is optional and uses a small amount of plan allowance.';

  @override
  String get chatGptModelsPending =>
      'Your account is saved on this device, but available models could not be loaded. Load models again to finish setup.';

  @override
  String get chatGptAccountUnnamed => 'ChatGPT account';

  @override
  String get chatGptRegistrationPending =>
      'Authorization is incomplete. Sign in again.';

  @override
  String get chatGptUsage => 'Manage ChatGPT usage';

  @override
  String get chatGptRequestError =>
      'ChatGPT request failed. Sign in again or check your plan access.';

  @override
  String get chatGptIdentityError =>
      'ChatGPT identity could not be verified. Please sign in again.';

  @override
  String get chatGptLoginCancelled =>
      'ChatGPT sign-in was cancelled or expired. Please try again.';

  @override
  String get chatGptLoginBusy => 'ChatGPT sign-in is already running.';

  @override
  String get chatGptScopeError =>
      'ChatGPT plan access was not granted. Enable it when signing in.';

  @override
  String get chatGptSignInFirst => 'Sign in to ChatGPT in Settings first.';

  @override
  String get chatGptInterrupted =>
      'ChatGPT request was interrupted. Please try again.';

  @override
  String get chatGptIncomplete =>
      'ChatGPT could not complete the response. Check your plan usage and try again.';

  @override
  String get chatGptReady =>
      'ChatGPT is ready. New questions will use your selected account.';

  @override
  String get chatGptSignedOut => 'Signed out of ChatGPT.';

  @override
  String get chatGptRevocationUnconfirmed =>
      'Signed out locally. Disconnect OmniQuiz in ChatGPT Settings to confirm revocation.';

  @override
  String get libraryStorageDetails => 'Storage and library details';

  @override
  String get chatGptSignInAgain => 'Sign in again';

  @override
  String get chatGptDetails => 'How subscription access works';

  @override
  String get updateTitle => 'App updates';

  @override
  String get updateAutoCheck => 'Check for updates at startup';

  @override
  String get updateHelp =>
      'Only checks for new versions. Downloads start when you choose Update.';

  @override
  String updateVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateCurrent => 'You are using the latest stable version.';

  @override
  String get updateNoRelease => 'No stable release has been published yet.';

  @override
  String updateFound(String version) {
    return 'New version $version';
  }

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateReady =>
      'Download verified. Continue installation when ready.';

  @override
  String get updateInstalling => 'Preparing installation…';

  @override
  String get updateFailed =>
      'Could not check, download or install the update. Retry or use the official download page.';

  @override
  String get updateCancelled =>
      'Download cancelled. You can keep using this version.';

  @override
  String get updatePreferenceFailed =>
      'Could not save the update preference. Please try again.';

  @override
  String get updateDetails => 'View update';

  @override
  String get updateWebsite => 'Official download page';

  @override
  String get updateOptional =>
      'Updates are optional. Remind me later or skip without affecting your use.';

  @override
  String get updateNoNotes => 'See the official release page for details.';

  @override
  String get updateUnsupported =>
      'This platform has no compatible installer for this release. Use the official page for available builds and installation instructions.';

  @override
  String get updateInstallHelp =>
      'Installation may close and restart OmniQuiz. Your libraries and progress are kept. Follow any system permission prompts.';

  @override
  String get updateLater => 'Remind me later';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateCancelDownload => 'Cancel download';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateInstall => 'Continue installation';

  @override
  String get updateInstallPermission =>
      'Allow OmniQuiz to install updates in system settings, then return and choose Continue installation.';

  @override
  String get pdfSourceUnavailable =>
      'The original PDF is missing, changed or unavailable. Showing the saved text excerpt instead; reconnect or reimport the source to view the page.';

  @override
  String get questionGood => 'Good';

  @override
  String get feedbackNextGeneration =>
      'Saved. Your feedback will guide subsequent generation.';

  @override
  String get questionBad => 'Not good';

  @override
  String get questionError => 'Something wrong?';

  @override
  String get questionFeedbackHelp =>
      'Your rating and optional note will accompany the next generation request to improve subsequent questions. Marking an error hides this question but keeps answer history. Nothing is reported to the developer automatically.';

  @override
  String get questionErrorNote => 'What is wrong? (optional)';

  @override
  String get markQuestionError => 'Mark error and skip';

  @override
  String generationElapsed(int seconds, int count) {
    return 'Elapsed ${seconds}s · $count questions available';
  }

  @override
  String get slowGenerationHelp =>
      'This model is taking longer. You can answer cached questions or end practice to cancel. A timeout will not trigger an automatic paid retry.';

  @override
  String get stageReading => 'Reading study material excerpts…';

  @override
  String get stageGuidance =>
      'Reading sample papers and question requirements…';

  @override
  String get stageRequesting => 'Waiting for the model to write questions…';

  @override
  String get stageValidating => 'Checking answers, citations and duplicates…';

  @override
  String get stageSaving => 'Saving verified questions to this library…';

  @override
  String get stageRetrying =>
      'The provider is busy. Waiting before a limited retry…';

  @override
  String get unsafeMetadata =>
      'The library metadata contains a link or another unsafe path. Use ordinary folders and files.';

  @override
  String get feedbackSaveError =>
      'Could not save question feedback. Please try again.';

  @override
  String get configureAi => 'Configure AI';

  @override
  String get openAiCompatible => 'OpenAI-compatible API';

  @override
  String get generationConnection => 'AI for new questions';

  @override
  String get switchConnection => 'Switch';

  @override
  String get noActiveConnection => 'No AI connection selected';

  @override
  String get connectionSelectionHelp =>
      'Save multiple connections and explicitly select one for new questions. Switching keeps existing questions. A failed connection never falls back to another automatically.';

  @override
  String get savedConnections => 'Saved connections';

  @override
  String get addConnection => 'Add connection';

  @override
  String get subscriptionConnectionHelp =>
      'Sign in with a ChatGPT account and choose a model.';

  @override
  String get compatibleConnectionHelp =>
      'Use the official OpenAI API or any compatible service, including CLIProxyAPI.';

  @override
  String get currentConnection => 'Current';

  @override
  String get useConnection => 'Use';

  @override
  String get editConnection => 'Edit';

  @override
  String get deleteConnection => 'Delete connection';

  @override
  String deleteConnectionHelp(String name) {
    return 'Delete “$name”? If it is active, generation stops without selecting another connection. Existing questions stay.';
  }

  @override
  String get connectionNeedsLogin => 'Sign-in required';

  @override
  String get connectionName => 'Connection name';

  @override
  String get subscriptionSaveHelp =>
      'Sign-in saves the account and available model automatically. Only your first connection is selected automatically; adding another does not replace the current choice.';

  @override
  String get compatibleAddressHelp =>
      'Defaults to the official OpenAI address. For CLIProxyAPI or another compatible service, enter its API base URL ending in /v1.';

  @override
  String get connectionSaveHelp =>
      'Testing is optional. Save keeps this connection independently; Save and use explicitly selects it for subsequent generation.';

  @override
  String get saveAndUseConnection => 'Save and use';

  @override
  String get saveConnection => 'Save connection';

  @override
  String get guidancePreservesQuestions =>
      'Saving keeps existing questions and your current answer selection. Updated requirements apply to subsequent generation only.';

  @override
  String get invalidConnections =>
      'Saved AI connections could not be read. Your existing configuration was kept.';

  @override
  String get connectionNameError =>
      'Enter a connection name (1–80 characters).';

  @override
  String get connectionSaveError =>
      'Could not save AI connections. Please try again.';

  @override
  String get connectionSavedActive =>
      'Connection saved and selected for new questions.';

  @override
  String get connectionSavedInactive =>
      'Connection saved. The current AI connection is unchanged.';

  @override
  String get connectionRemoved =>
      'Connection removed. Other saved connections were kept.';

  @override
  String get questionsPerBatch => 'Questions per batch';

  @override
  String get questionsPerBatchHelp =>
      'Request 1–50 questions at a time. Default: 10.';

  @override
  String get questionsPerBatchError => 'Enter a whole number from 1 to 50.';

  @override
  String get refillThreshold => 'Auto-refill threshold';

  @override
  String get refillThresholdHelp =>
      'Refill at or below this unanswered count (0–100; default: 10). Use 0 to refill only when empty.';

  @override
  String get refillThresholdError => 'Enter a whole number from 0 to 100.';

  @override
  String get hideSource => 'Hide source';

  @override
  String sourcePage(String page) {
    return 'Page $page';
  }

  @override
  String get interfaceSettings => 'Appearance & language';

  @override
  String get chatGptSignInCancelled => 'ChatGPT sign-in cancelled.';
}
