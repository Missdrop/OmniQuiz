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
