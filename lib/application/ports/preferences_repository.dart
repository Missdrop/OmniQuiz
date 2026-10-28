// Keeps global interface preferences independent from AI profiles and per-library authoring data.

/// Stores the global interface-language preference only.
abstract interface class PreferencesRepository {
  /// Missing values resolve to the operating system rather than a hard-coded locale.
  Future<String?> loadInterfaceLanguage();

  /// Stores a language code or the explicit `system` sentinel.
  Future<void> saveInterfaceLanguage(String language);
}

/// Stores global appearance without changing question-generation epochs.
abstract interface class AppearancePreferencesRepository {
  /// Missing values use system brightness; this does not read a provider profile.
  Future<String?> loadThemeMode();

  /// Stores only the mode; changing appearance must not invalidate generation.
  Future<void> saveThemeMode(String mode);
}

/// Stores the shared output-language choice used by both connection modes.
abstract interface class QuestionLanguagePreferencesRepository {
  /// The shared choice is independent from the currently displayed UI language.
  Future<String?> loadQuestionLanguage();

  /// Stores an explicit output language or resolves the system locale per request.
  Future<void> saveQuestionLanguage(String language);
}
