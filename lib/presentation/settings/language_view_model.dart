import 'package:flutter/material.dart';

import '../../application/ports/preferences_repository.dart';

/// UI preference is independent of AI profiles and never invalidates generation.
class LanguageViewModel extends ChangeNotifier {
  LanguageViewModel(this.repository);
  final PreferencesRepository repository;
  String _language = 'system';
  String get language => _language;
  Locale? get locale => _language == 'system' ? null : Locale(_language);
  bool saving = false;
  bool saveFailed = false;

  Future<void> load() async {
    final saved = await repository.loadInterfaceLanguage();
    _language = ['en', 'zh'].contains(saved) ? saved! : 'system';
  }

  Future<void> select(String language) async {
    if (saving || !['system', 'en', 'zh'].contains(language)) return;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await repository.saveInterfaceLanguage(language);
      _language = language;
    } catch (_) {
      saveFailed = true;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
