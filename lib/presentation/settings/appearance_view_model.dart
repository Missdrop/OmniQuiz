// Saves appearance before applying it, retaining the last valid mode if persistence fails.

import 'package:flutter/material.dart';

import '../../application/ports/preferences_repository.dart';

/// Persists light/dark/system choices independently of practice-session lifetime.
class AppearanceViewModel extends ChangeNotifier {
  AppearanceViewModel(this.repository);
  final AppearancePreferencesRepository repository;
  ThemeMode mode = ThemeMode.system;
  bool saving = false, saveFailed = false;
  bool _disposed = false;

  Future<void> load() async {
    final saved = await repository.loadThemeMode();
    mode = ThemeMode.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode value) async {
    if (saving || _disposed) return;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await repository.saveThemeMode(value.name);
      mode = value;
    } catch (_) {
      saveFailed = true;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
