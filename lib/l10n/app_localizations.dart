import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @practice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practice;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Make knowledge yours.'**
  String get tagline;

  /// No description provided for @localByDesign.
  ///
  /// In en, this message translates to:
  /// **'Local by design'**
  String get localByDesign;

  /// No description provided for @libraryEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your learning space'**
  String get libraryEyebrow;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'A little practice. A lot of progress.'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your notes. Build understanding, one question at a time.'**
  String get librarySubtitle;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @questionsReady.
  ///
  /// In en, this message translates to:
  /// **'Questions ready'**
  String get questionsReady;

  /// No description provided for @answersGiven.
  ///
  /// In en, this message translates to:
  /// **'Answers given'**
  String get answersGiven;

  /// No description provided for @toRevisit.
  ///
  /// In en, this message translates to:
  /// **'To revisit'**
  String get toRevisit;

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'Import files'**
  String get importFiles;

  /// No description provided for @importFolder.
  ///
  /// In en, this message translates to:
  /// **'Import folder'**
  String get importFolder;

  /// No description provided for @goToPractice.
  ///
  /// In en, this message translates to:
  /// **'Go to practice'**
  String get goToPractice;

  /// No description provided for @supportedFiles.
  ///
  /// In en, this message translates to:
  /// **'TXT, Markdown & text PDF · up to 20 MB per file'**
  String get supportedFiles;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your next chapter starts here'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a document to turn it into practice questions.\nYour materials stay on this device until you choose to generate.'**
  String get libraryEmptyBody;

  /// No description provided for @trySample.
  ///
  /// In en, this message translates to:
  /// **'Try sample notes'**
  String get trySample;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @removeDocument.
  ///
  /// In en, this message translates to:
  /// **'Remove document'**
  String get removeDocument;

  /// No description provided for @removeDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this document?'**
  String get removeDocumentTitle;

  /// No description provided for @removeDocumentBody.
  ///
  /// In en, this message translates to:
  /// **'Its questions will leave the practice and review queues. Your answer history will be retained.'**
  String get removeDocumentBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @reviewPracticeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Build lasting knowledge'**
  String get reviewPracticeEyebrow;

  /// No description provided for @practiceEyebrow.
  ///
  /// In en, this message translates to:
  /// **'One question at a time'**
  String get practiceEyebrow;

  /// No description provided for @reviewPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'A second look.'**
  String get reviewPracticeTitle;

  /// No description provided for @practiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your flow.'**
  String get practiceTitle;

  /// No description provided for @reviewPracticeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recall it first. Then read the explanation.'**
  String get reviewPracticeSubtitle;

  /// No description provided for @practiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh questions from your materials, ready before you need them.'**
  String get practiceSubtitle;

  /// No description provided for @practiceScope.
  ///
  /// In en, this message translates to:
  /// **'Practice scope'**
  String get practiceScope;

  /// No description provided for @allMaterials.
  ///
  /// In en, this message translates to:
  /// **'All materials'**
  String get allMaterials;

  /// No description provided for @pauseGeneration.
  ///
  /// In en, this message translates to:
  /// **'Pause generation'**
  String get pauseGeneration;

  /// No description provided for @generateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate practice questions?'**
  String get generateTitle;

  /// No description provided for @generateBody.
  ///
  /// In en, this message translates to:
  /// **'Relevant excerpts will be sent to your configured AI provider. Generation uses your API balance and automatically replenishes a buffer of up to 20 questions while practice is active. You can pause at any time.'**
  String get generateBody;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @generateQuestions.
  ///
  /// In en, this message translates to:
  /// **'Generate questions'**
  String get generateQuestions;

  /// No description provided for @backToFresh.
  ///
  /// In en, this message translates to:
  /// **'Back to fresh questions'**
  String get backToFresh;

  /// No description provided for @reviewCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You’re caught up for now'**
  String get reviewCaughtUp;

  /// No description provided for @firstQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ready for your first question?'**
  String get firstQuestion;

  /// No description provided for @reviewCaughtUpBody.
  ///
  /// In en, this message translates to:
  /// **'Come back when your next review is due, or choose another item from Review.'**
  String get reviewCaughtUpBody;

  /// No description provided for @firstQuestionBody.
  ///
  /// In en, this message translates to:
  /// **'Import your notes, connect an AI provider, then start generating.\nOnce saved, questions work offline too.'**
  String get firstQuestionBody;

  /// No description provided for @openLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get openLibrary;

  /// No description provided for @reviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Review queue'**
  String get reviewQueue;

  /// No description provided for @setUpAi.
  ///
  /// In en, this message translates to:
  /// **'Set up AI'**
  String get setUpAi;

  /// No description provided for @singleChoice.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get singleChoice;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @checkAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get checkAnswer;

  /// No description provided for @hideQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide this question?'**
  String get hideQuestionTitle;

  /// No description provided for @hideQuestionBody.
  ///
  /// In en, this message translates to:
  /// **'If the question is incorrect or ambiguous, remove it from practice and review. This report stays on your device.'**
  String get hideQuestionBody;

  /// No description provided for @hideQuestion.
  ///
  /// In en, this message translates to:
  /// **'Hide question'**
  String get hideQuestion;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @correctAnswer.
  ///
  /// In en, this message translates to:
  /// **'Well done.'**
  String get correctAnswer;

  /// No description provided for @wrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'A useful mistake.'**
  String get wrongAnswer;

  /// No description provided for @fullSource.
  ///
  /// In en, this message translates to:
  /// **'Read the full source excerpt'**
  String get fullSource;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated. Check the source if an answer seems wrong.'**
  String get aiDisclaimer;

  /// No description provided for @reviewEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Mistakes become progress'**
  String get reviewEyebrow;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Worth another look.'**
  String get reviewTitle;

  /// No description provided for @reviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Missed questions return here. Three correct reviews graduate a question from this queue.'**
  String get reviewSubtitle;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'A fresh start'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your missed questions will appear here. Keep practicing to discover what needs another look.'**
  String get reviewEmptyBody;

  /// No description provided for @dueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get dueNow;

  /// No description provided for @reviewEarly.
  ///
  /// In en, this message translates to:
  /// **'Review early'**
  String get reviewEarly;

  /// No description provided for @reviewNow.
  ///
  /// In en, this message translates to:
  /// **'Review now'**
  String get reviewNow;

  /// No description provided for @settingsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Make it yours'**
  String get settingsEyebrow;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI. Your choice.'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect an OpenAI-compatible Chat Completions API. No OmniQuiz account or server.'**
  String get settingsSubtitle;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI provider'**
  String get aiProvider;

  /// No description provided for @apiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get apiBaseUrl;

  /// No description provided for @apiBaseUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Include /v1 if your provider requires it. Do not append /chat/completions.'**
  String get apiBaseUrlHelp;

  /// No description provided for @modelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get modelId;

  /// No description provided for @modelHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a model available from your provider'**
  String get modelHint;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @pasteKey.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key'**
  String get pasteKey;

  /// No description provided for @keepKey.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the saved key'**
  String get keepKey;

  /// No description provided for @hideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get hideKey;

  /// No description provided for @showKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get showKey;

  /// No description provided for @noKey.
  ///
  /// In en, this message translates to:
  /// **'This endpoint does not require a key'**
  String get noKey;

  /// No description provided for @jsonMode.
  ///
  /// In en, this message translates to:
  /// **'JSON response mode'**
  String get jsonMode;

  /// No description provided for @jsonModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Enable only if your provider supports response_format: json_object.'**
  String get jsonModeHelp;

  /// No description provided for @questionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Question language'**
  String get questionLanguage;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Generation sends selected source excerpts to your chosen provider. Connection tests make a small paid API request. Keys are kept in system secure storage; documents and study progress stay local.'**
  String get privacyNotice;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get appLanguage;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get systemLanguage;

  /// No description provided for @appLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies immediately and is saved on this device. Question language is configured separately below.'**
  String get appLanguageHelp;

  /// No description provided for @questionLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to newly generated questions and explanations. Existing questions keep their original language.'**
  String get questionLanguageHelp;

  /// No description provided for @languageSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the interface language. Please try again.'**
  String get languageSaveError;

  /// No description provided for @startupError.
  ///
  /// In en, this message translates to:
  /// **'OmniQuiz could not open local storage. Check available disk space and application permissions, then restart.'**
  String get startupError;

  /// No description provided for @readyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String readyCount(int count);

  /// No description provided for @documentDetails.
  ///
  /// In en, this message translates to:
  /// **'{count} source excerpts · imported {date}'**
  String documentDetails(int count, String date);

  /// No description provided for @reviewProgress.
  ///
  /// In en, this message translates to:
  /// **'{streak}/3 correct reviews · {mistakes} missed'**
  String reviewProgress(int streak, int mistakes);

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueDate(String date);

  /// No description provided for @sourceName.
  ///
  /// In en, this message translates to:
  /// **'SOURCE · {name}'**
  String sourceName(String name);

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} imported · {unchanged} unchanged'**
  String importSummary(int count, int unchanged);

  /// No description provided for @bufferReady.
  ///
  /// In en, this message translates to:
  /// **'{count} questions ready'**
  String bufferReady(int count);

  /// No description provided for @retryGeneration.
  ///
  /// In en, this message translates to:
  /// **'Retrying generation ({attempt}/3)…'**
  String retryGeneration(int attempt);

  /// No description provided for @httpError.
  ///
  /// In en, this message translates to:
  /// **'Provider returned HTTP {code}. Check the base URL, model and JSON mode.'**
  String httpError(int code);

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} exceeds the 20 MB file limit.'**
  String fileTooLarge(String name);

  /// No description provided for @textLocation.
  ///
  /// In en, this message translates to:
  /// **'Text · characters {start}–{end}'**
  String textLocation(String start, String end);

  /// No description provided for @pageLocation.
  ///
  /// In en, this message translates to:
  /// **'Page {page} · characters {start}–{end}'**
  String pageLocation(String page, String start, String end);

  /// No description provided for @invalidQuestion.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an invalid question.'**
  String get invalidQuestion;

  /// No description provided for @invalidProfile.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS API base URL and a model name. HTTP is allowed only for localhost.'**
  String get invalidProfile;

  /// No description provided for @loadLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your library.'**
  String get loadLibraryError;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Check file permissions and try again.'**
  String get importError;

  /// No description provided for @removeError.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this document.'**
  String get removeError;

  /// No description provided for @loadQuestionsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load questions.'**
  String get loadQuestionsError;

  /// No description provided for @saveAnswerError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your answer. Try again.'**
  String get saveAnswerError;

  /// No description provided for @loadReviewError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your review queue.'**
  String get loadReviewError;

  /// No description provided for @loadSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load provider settings.'**
  String get loadSettingsError;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved. Your key is stored securely on this device.'**
  String get settingsSaved;

  /// No description provided for @saveSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings.'**
  String get saveSettingsError;

  /// No description provided for @testKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the API key for this endpoint before testing.'**
  String get testKeyRequired;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful. The model returned valid JSON.'**
  String get connectionSuccess;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed. Check secure storage and connectivity.'**
  String get connectionError;

  /// No description provided for @readyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are'**
  String get readyStatus;

  /// No description provided for @pausedStatus.
  ///
  /// In en, this message translates to:
  /// **'Generation paused · cached questions remain available'**
  String get pausedStatus;

  /// No description provided for @configureFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure your AI provider in Settings first.'**
  String get configureFirst;

  /// No description provided for @importFirst.
  ///
  /// In en, this message translates to:
  /// **'Import study materials first.'**
  String get importFirst;

  /// No description provided for @generatingStatus.
  ///
  /// In en, this message translates to:
  /// **'Preparing your next questions…'**
  String get generatingStatus;

  /// No description provided for @changedStatus.
  ///
  /// In en, this message translates to:
  /// **'Materials or settings changed. Start generation again.'**
  String get changedStatus;

  /// No description provided for @savedQuestionsStatus.
  ///
  /// In en, this message translates to:
  /// **'New questions saved'**
  String get savedQuestionsStatus;

  /// No description provided for @generateError.
  ///
  /// In en, this message translates to:
  /// **'Could not save or generate questions. Please try again.'**
  String get generateError;

  /// No description provided for @fileLimit.
  ///
  /// In en, this message translates to:
  /// **'File exceeds 20 MB.'**
  String get fileLimit;

  /// No description provided for @textLimit.
  ///
  /// In en, this message translates to:
  /// **'Extracted text exceeds 1 million characters. Split the file.'**
  String get textLimit;

  /// No description provided for @noText.
  ///
  /// In en, this message translates to:
  /// **'No readable text found.'**
  String get noText;

  /// No description provided for @readError.
  ///
  /// In en, this message translates to:
  /// **'Could not read this file.'**
  String get readError;

  /// No description provided for @keyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key or explicitly select an endpoint without a key.'**
  String get keyRequired;

  /// No description provided for @newKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a key for the new endpoint, or explicitly select no key.'**
  String get newKeyRequired;

  /// No description provided for @secureSaveError.
  ///
  /// In en, this message translates to:
  /// **'Secure storage is unavailable. API key was not saved.'**
  String get secureSaveError;

  /// No description provided for @encodingError.
  ///
  /// In en, this message translates to:
  /// **'Text files must use UTF-8 encoding.'**
  String get encodingError;

  /// No description provided for @documentLimit.
  ///
  /// In en, this message translates to:
  /// **'This document is too large. Split it into smaller files.'**
  String get documentLimit;

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'No text found. Scanned PDFs need OCR before import.'**
  String get scanError;

  /// No description provided for @formatError.
  ///
  /// In en, this message translates to:
  /// **'Supported formats: TXT, Markdown, and text-based PDF.'**
  String get formatError;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'API authorization failed. Check your key and model access.'**
  String get authError;

  /// No description provided for @quotaError.
  ///
  /// In en, this message translates to:
  /// **'Provider rate limit or quota reached. Try again later.'**
  String get quotaError;

  /// No description provided for @providerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI provider is temporarily unavailable.'**
  String get providerUnavailable;

  /// No description provided for @responseLimit.
  ///
  /// In en, this message translates to:
  /// **'Provider response exceeded the size limit.'**
  String get responseLimit;

  /// No description provided for @outputTruncated.
  ///
  /// In en, this message translates to:
  /// **'Provider output was truncated. Try a model with a larger output limit.'**
  String get outputTruncated;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Generation timed out. A retry may incur another API charge.'**
  String get timeoutError;

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'The provider returned invalid JSON.'**
  String get invalidJson;

  /// No description provided for @incompatibleResponse.
  ///
  /// In en, this message translates to:
  /// **'The provider response is not compatible with Chat Completions.'**
  String get incompatibleResponse;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the provider. Check your connection and API address.'**
  String get networkError;

  /// No description provided for @probeJsonError.
  ///
  /// In en, this message translates to:
  /// **'The model responded, but did not follow the JSON test. Try another model.'**
  String get probeJsonError;

  /// No description provided for @modelJsonError.
  ///
  /// In en, this message translates to:
  /// **'The model did not return valid JSON. Try JSON mode or a different model.'**
  String get modelJsonError;

  /// No description provided for @secureReadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot access secure storage. Unlock your device and try again.'**
  String get secureReadError;

  /// No description provided for @missingCredentials.
  ///
  /// In en, this message translates to:
  /// **'API credentials are missing. Save them in Settings.'**
  String get missingCredentials;

  /// No description provided for @noQuestions.
  ///
  /// In en, this message translates to:
  /// **'The provider returned no question list.'**
  String get noQuestions;

  /// No description provided for @staleQuestion.
  ///
  /// In en, this message translates to:
  /// **'This question is no longer available. Choose another question.'**
  String get staleQuestion;

  /// No description provided for @invalidAnswer.
  ///
  /// In en, this message translates to:
  /// **'Invalid answer submission.'**
  String get invalidAnswer;

  /// No description provided for @noNewQuestions.
  ///
  /// In en, this message translates to:
  /// **'No new valid questions were generated. Try another source or model.'**
  String get noNewQuestions;

  /// No description provided for @invalidBatch.
  ///
  /// In en, this message translates to:
  /// **'No valid, new questions were returned. Try another model or add more material.'**
  String get invalidBatch;

  /// No description provided for @fileReadError.
  ///
  /// In en, this message translates to:
  /// **'The selected file could not be read. Try copying it to this device first.'**
  String get fileReadError;

  /// No description provided for @useFiles.
  ///
  /// In en, this message translates to:
  /// **'Use Import files on this device.'**
  String get useFiles;

  /// No description provided for @folderLimit.
  ///
  /// In en, this message translates to:
  /// **'Import at most 100 files / 100 MB at once. Select a smaller folder.'**
  String get folderLimit;

  /// No description provided for @currentLibrary.
  ///
  /// In en, this message translates to:
  /// **'Current library'**
  String get currentLibrary;

  /// No description provided for @createLibrary.
  ///
  /// In en, this message translates to:
  /// **'Create library'**
  String get createLibrary;

  /// No description provided for @libraryName.
  ///
  /// In en, this message translates to:
  /// **'Library name'**
  String get libraryName;

  /// No description provided for @useExistingFolder.
  ///
  /// In en, this message translates to:
  /// **'Use an existing folder'**
  String get useExistingFolder;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get chooseFolder;

  /// No description provided for @folderIncludesSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder, including its subfolders.'**
  String get folderIncludesSubfolders;

  /// No description provided for @managedFolderDescription.
  ///
  /// In en, this message translates to:
  /// **'Create an app-managed folder. Imported files will be copied there.'**
  String get managedFolderDescription;

  /// No description provided for @mobileLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'This device uses app-managed folders. Add materials with Import files.'**
  String get mobileLibraryDescription;

  /// No description provided for @libraryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and choose a folder.'**
  String get libraryNameRequired;

  /// No description provided for @createLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Could not create library. Check folder access and use non-overlapping folders.'**
  String get createLibraryError;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @scanFolder.
  ///
  /// In en, this message translates to:
  /// **'Scan folder'**
  String get scanFolder;

  /// No description provided for @libraryIsolationDescription.
  ///
  /// In en, this message translates to:
  /// **'Questions, mistakes and progress belong to this library. Folders scan on launch, switch and resume; scan manually anytime.'**
  String get libraryIsolationDescription;

  /// No description provided for @openLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this library. Try again.'**
  String get openLibraryError;

  /// No description provided for @scanFolderError.
  ///
  /// In en, this message translates to:
  /// **'Could not scan the library folder. Check that it is connected and grant folder access again.'**
  String get scanFolderError;

  /// No description provided for @folderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Library folder is unavailable. Reconnect it and scan again.'**
  String get folderUnavailable;

  /// No description provided for @copyLibraryFileError.
  ///
  /// In en, this message translates to:
  /// **'Cannot copy this file into the library folder.'**
  String get copyLibraryFileError;

  /// No description provided for @grantFolderAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant folder access'**
  String get grantFolderAccess;

  /// No description provided for @grantFolderError.
  ///
  /// In en, this message translates to:
  /// **'Choose the same library folder to restore access.'**
  String get grantFolderError;

  /// No description provided for @removeIndexedDocumentBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the document and its questions from practice, but keeps the original file. Scanning the folder will import it again. To exclude it permanently, move the file out of this folder.'**
  String get removeIndexedDocumentBody;

  /// No description provided for @importZip.
  ///
  /// In en, this message translates to:
  /// **'Import ZIP'**
  String get importZip;

  /// No description provided for @zipSupportedFiles.
  ///
  /// In en, this message translates to:
  /// **'TXT, Markdown & text PDF · 20 MB per file · ZIP: 100 MB compressed / extracted, up to 1000 entries'**
  String get zipSupportedFiles;

  /// No description provided for @zipReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read this ZIP. Use an unencrypted ZIP with standard compression.'**
  String get zipReadError;

  /// No description provided for @zipSelectedReadError.
  ///
  /// In en, this message translates to:
  /// **'The selected ZIP could not be read.'**
  String get zipSelectedReadError;

  /// No description provided for @zipArchiveLimit.
  ///
  /// In en, this message translates to:
  /// **'ZIP exceeds the 100 MB archive limit.'**
  String get zipArchiveLimit;

  /// No description provided for @zipEntryLimit.
  ///
  /// In en, this message translates to:
  /// **'ZIP contains more than 1000 entries. Split the archive.'**
  String get zipEntryLimit;

  /// No description provided for @zipUnsafePaths.
  ///
  /// In en, this message translates to:
  /// **'ZIP contains unsafe paths or links. Nothing was imported.'**
  String get zipUnsafePaths;

  /// No description provided for @zipInvalidSizes.
  ///
  /// In en, this message translates to:
  /// **'ZIP contains invalid file sizes.'**
  String get zipInvalidSizes;

  /// No description provided for @zipExpandedLimit.
  ///
  /// In en, this message translates to:
  /// **'ZIP expands beyond the 100 MB limit.'**
  String get zipExpandedLimit;

  /// No description provided for @zipDuplicatePaths.
  ///
  /// In en, this message translates to:
  /// **'ZIP contains unsafe or duplicate file paths.'**
  String get zipDuplicatePaths;

  /// No description provided for @zipMaterialLimit.
  ///
  /// In en, this message translates to:
  /// **'A material in the ZIP exceeds the 20 MB file limit.'**
  String get zipMaterialLimit;

  /// No description provided for @zipNoMaterials.
  ///
  /// In en, this message translates to:
  /// **'No supported materials in ZIP. Include TXT, Markdown or text PDF.'**
  String get zipNoMaterials;

  /// No description provided for @zipDamaged.
  ///
  /// In en, this message translates to:
  /// **'ZIP is damaged. Nothing was imported.'**
  String get zipDamaged;

  /// No description provided for @zipImportError.
  ///
  /// In en, this message translates to:
  /// **'Could not import ZIP. Check storage space and file permissions.'**
  String get zipImportError;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your libraries'**
  String get backupTitle;

  /// No description provided for @backupHelp.
  ///
  /// In en, this message translates to:
  /// **'Save all libraries, materials, questions and progress. AI settings and API keys are excluded. Backups contain your private study data.'**
  String get backupHelp;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Restore a previously exported OmniQuiz backup as new libraries. Your existing libraries and AI settings will be kept.'**
  String get restoreBackupHelp;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get backupSaved;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed. Check storage space and folder access.'**
  String get backupFailed;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} libraries. Switch libraries to open them.'**
  String backupRestored(int count);

  /// No description provided for @backupMissingOriginals.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. {count} original files were unavailable; their extracted text and learning records were preserved.'**
  String backupMissingOriginals(int count);

  /// No description provided for @backupTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Backup is too large.'**
  String get backupTooLarge;

  /// No description provided for @backupSourceError.
  ///
  /// In en, this message translates to:
  /// **'A source file could not be backed up.'**
  String get backupSourceError;

  /// No description provided for @backupReadError.
  ///
  /// In en, this message translates to:
  /// **'Backup could not be read.'**
  String get backupReadError;

  /// No description provided for @backupRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Backup is invalid or could not be restored. Your existing libraries were kept.'**
  String get backupRestoreError;

  /// No description provided for @maintenanceBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish the current operation before backing up or restoring.'**
  String get maintenanceBusy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
