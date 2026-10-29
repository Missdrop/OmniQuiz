// Maps known application diagnostics at the UI boundary while preserving user-provided filenames.

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
export 'app_localizations.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Adapts existing application diagnostics at the presentation boundary.
/// Domain code and persisted source references remain independent of Flutter.
/// Only known messages are translated; document text and AI output are untouched.
extension LocalizedDiagnostics on AppLocalizations {
  String diagnostic(String message) {
    if (message.contains('\n')) {
      return message.split('\n').map(diagnostic).join('\n');
    }
    final known = <String, String>{
      'Invalid saved AI connections.': invalidConnections,
      'Enter a connection name (1–80 characters).': connectionNameError,
      'Could not save AI connections. Please try again.': connectionSaveError,
      'Connection saved and selected for new questions.': connectionSavedActive,
      'Connection saved. The current AI connection is unchanged.':
          connectionSavedInactive,
      'Connection removed. Other saved connections were kept.':
          connectionRemoved,
      'Reading study material excerpts…': stageReading,
      'Reading sample papers and question requirements…': stageGuidance,
      'Waiting for the model to write questions…': stageRequesting,
      'Checking answers, citations and duplicates…': stageValidating,
      'Saving verified questions to this library…': stageSaving,
      'The provider is busy. Waiting before a limited retry…': stageRetrying,
      'Library metadata contains an unsafe path.': unsafeMetadata,
      'Could not save question feedback. Please try again.': feedbackSaveError,
      'Question guidance exceeds its size limits.': guidanceLimitError,
      'Invalid or duplicate reference examples.': guidanceInvalidExamples,
      'Could not load question guidance. Save it again to repair it.':
          guidanceLoadError,
      'Could not import reference examples.': guidanceImportError,
      'Could not save question guidance. Please try again.': guidanceSaveError,
      'Account saved. Could not load available models. Load models again to finish setup.':
          chatGptModelsPending,
      'ChatGPT account': chatGptAccountUnnamed,
      'Registration pending': chatGptRegistrationPending,
      "ChatGPT request failed. Sign in again or check your plan access.":
          chatGptRequestError,
      "ChatGPT identity could not be verified. Please sign in again.":
          chatGptIdentityError,
      'ChatGPT sign-in cancelled.': chatGptSignInCancelled,
      "ChatGPT sign-in was cancelled or expired. Please try again.":
          chatGptLoginCancelled,
      "ChatGPT sign-in is already running.": chatGptLoginBusy,
      "ChatGPT plan access was not granted. Enable it when signing in.":
          chatGptScopeError,
      "Sign in to ChatGPT in Settings first.": chatGptSignInFirst,
      "ChatGPT request was interrupted. Please try again.": chatGptInterrupted,
      "ChatGPT could not complete the response. Check your plan usage and try again.":
          chatGptIncomplete,
      "ChatGPT is ready. New questions will use your selected account.":
          chatGptReady,
      "Signed out of ChatGPT.": chatGptSignedOut,
      "Signed out locally. Disconnect OmniQuiz in ChatGPT Settings to confirm revocation.":
          chatGptRevocationUnconfirmed,
      'Could not load models. Check the endpoint and key, or enter a model manually.':
          loadModelsError,
      'No models are available. Sign in to a provider on your gateway, or enter a model manually.':
          noModelsError,
      'Scan cancelled. Completed imports were kept.': scanCancelled,
      'Could not restore this excluded file.': restoreExcludedError,
      'Could not save material selection. Please try again.':
          materialSelectionError,
      'Finish the current operation before backing up or restoring.':
          maintenanceBusy,
      'Backup is too large.': backupTooLarge,
      'A source file could not be backed up.': backupSourceError,
      'Backup could not be read.': backupReadError,
      'Backup is invalid or could not be restored. Your existing libraries were kept.':
          backupRestoreError,

      'Could not read this ZIP. Use an unencrypted ZIP with standard compression.':
          zipReadError,
      'The selected ZIP could not be read.': zipSelectedReadError,
      'ZIP exceeds the 100 MB archive limit.': zipArchiveLimit,
      'ZIP contains more than 1000 entries. Split the archive.': zipEntryLimit,
      'ZIP contains unsafe paths or links. Nothing was imported.':
          zipUnsafePaths,
      'ZIP contains invalid file sizes.': zipInvalidSizes,
      'ZIP expands beyond the 100 MB limit.': zipExpandedLimit,
      'ZIP contains unsafe or duplicate file paths.': zipDuplicatePaths,
      'A material in the ZIP exceeds the 20 MB file limit.': zipMaterialLimit,
      'No supported materials in ZIP. Include TXT, Markdown or text PDF.':
          zipNoMaterials,
      'ZIP is damaged. Nothing was imported.': zipDamaged,
      'Could not import ZIP. Check storage space and file permissions.':
          zipImportError,

      'Could not scan the library folder. Check that it is connected and grant folder access again.':
          scanFolderError,
      'Library folder is unavailable. Reconnect it and scan again.':
          folderUnavailable,
      'Cannot copy this file into the library folder.': copyLibraryFileError,
      "The provider returned an invalid question.": invalidQuestion,
      "Enter an HTTPS API base URL and a model name. HTTP is allowed only for localhost.":
          invalidProfile,
      "Could not load your library.": loadLibraryError,
      "Import failed. Check file permissions and try again.": importError,
      "Could not remove this document.": removeError,
      "Could not load questions.": loadQuestionsError,
      "Could not save your answer. Try again.": saveAnswerError,
      "Could not load your review queue.": loadReviewError,
      "Could not load provider settings.": loadSettingsError,
      "Settings saved. Your key is stored securely on this device.":
          settingsSaved,
      "Could not save settings.": saveSettingsError,
      "Enter the API key for this endpoint before testing.": testKeyRequired,
      "Connection successful. The model returned valid JSON.":
          connectionSuccess,
      "Connection test failed. Check secure storage and connectivity.":
          connectionError,
      "Ready when you are": readyStatus,
      "Generation paused · cached questions remain available": pausedStatus,
      "Configure your AI provider in Settings first.": configureFirst,
      "Import study materials first.": importFirst,
      "Preparing your next questions…": generatingStatus,
      "Materials or settings changed. Start generation again.": changedStatus,
      "New questions saved": savedQuestionsStatus,
      "Could not save or generate questions. Please try again.": generateError,
      "File exceeds 20 MB.": fileLimit,
      "Extracted text exceeds 1 million characters. Split the file.": textLimit,
      "No readable text found.": noText,
      "Could not read this file.": readError,
      "Enter an API key or explicitly select an endpoint without a key.":
          keyRequired,
      "Enter a key for the new endpoint, or explicitly select no key.":
          newKeyRequired,
      "Secure storage is unavailable. API key was not saved.": secureSaveError,
      "Text files must use UTF-8 encoding.": encodingError,
      "This document is too large. Split it into smaller files.": documentLimit,
      "No text found. Scanned PDFs need OCR before import.": scanError,
      "Supported formats: TXT, Markdown, and text-based PDF.": formatError,
      "API authorization failed. Check your key and model access.": authError,
      "Provider rate limit or quota reached. Try again later.": quotaError,
      "The AI provider is temporarily unavailable.": providerUnavailable,
      "Provider response exceeded the size limit.": responseLimit,
      "Provider output was truncated. Try a model with a larger output limit.":
          outputTruncated,
      "Generation timed out. A retry may incur another API charge.":
          timeoutError,
      "The provider returned invalid JSON.": invalidJson,
      "The provider response is not compatible with Chat Completions.":
          incompatibleResponse,
      "Could not reach the provider. Check your connection and API address.":
          networkError,
      "The model responded, but did not follow the JSON test. Try another model.":
          probeJsonError,
      "The model did not return valid JSON. Try JSON mode or a different model.":
          modelJsonError,
      "Cannot access secure storage. Unlock your device and try again.":
          secureReadError,
      "API credentials are missing. Save them in Settings.": missingCredentials,
      "The provider returned no question list.": noQuestions,
      "This question is no longer available. Choose another question.":
          staleQuestion,
      "Invalid answer submission.": invalidAnswer,
      "No new valid questions were generated. Try another source or model.":
          noNewQuestions,
      "No valid, new questions were returned. Try another model or add more material.":
          invalidBatch,
      "The selected file could not be read. Try copying it to this device first.":
          fileReadError,
      "Use Import files on this device.": useFiles,
      "Import at most 100 files / 100 MB at once. Select a smaller folder.":
          folderLimit,
    };
    final direct = known[message];
    if (direct != null) return direct;
    for (final entry in known.entries) {
      final suffix = ': ${entry.key}';
      if (message.endsWith(suffix)) {
        return '${message.substring(0, message.length - suffix.length)}: ${entry.value}';
      }
    }
    var match = RegExp(r'^(\d+) imported · (\d+) unchanged$')
        .firstMatch(message);
    if (match != null) {
      return importSummary(int.parse(match[1]!), int.parse(match[2]!));
    }
    match = RegExp(r'^(\d+) excluded · (\d+) missing sources$')
        .firstMatch(message);
    if (match != null) {
      return scanSourceSummary(int.parse(match[1]!), int.parse(match[2]!));
    }
    match = RegExp(r'^(\d+) questions ready$').firstMatch(message);
    if (match != null) return bufferReady(int.parse(match[1]!));
    match = RegExp(r'^Retrying generation \((\d+)/3\)…$').firstMatch(message);
    if (match != null) return retryGeneration(int.parse(match[1]!));
    match = RegExp(
      r'^Provider returned HTTP (\d+)\. Check the base URL, model and JSON mode\.$',
    ).firstMatch(message);
    if (match != null) return httpError(int.parse(match[1]!));
    match = RegExp(r'^(.+) exceeds the 20 MB file limit\.$')
        .firstMatch(message);
    if (match != null) return fileTooLarge(match[1]!);
    return message;
  }

  String sourceLocation(String location) {
    var match = RegExp(r'^Text · characters (\d+)–(\d+)$').firstMatch(location);
    if (match != null) return textLocation(match[1]!, match[2]!);
    match = RegExp(r'^Page (\d+) · characters (\d+)–(\d+)$')
        .firstMatch(location);
    if (match != null) return pageLocation(match[1]!, match[2]!, match[3]!);
    return location;
  }
}
