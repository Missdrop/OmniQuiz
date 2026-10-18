abstract interface class PreferencesRepository {
  Future<String?> loadInterfaceLanguage();
  Future<void> saveInterfaceLanguage(String language);
}
