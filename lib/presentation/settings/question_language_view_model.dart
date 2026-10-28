// Resolves the shared generation language at request time so system-locale changes are respected.

import 'package:flutter/foundation.dart';

import '../../application/ports/preferences_repository.dart';

/// Resolves explicit or system language consistently for every AI connection.
class QuestionLanguageViewModel extends ChangeNotifier {
  QuestionLanguageViewModel(this.repository);
  final QuestionLanguagePreferencesRepository repository;
  String language = 'system';
  bool saving = false, saveFailed = false;
  bool _disposed = false;
  String get resolved => language == 'system'
      ? PlatformDispatcher.instance.locale.toLanguageTag()
      : language;

  Future<void> load() async {
    final saved = await repository.loadQuestionLanguage();
    language = ['简体中文', 'English'].contains(saved) ? saved! : 'system';
  }

  Future<void> select(String value) async {
    if (saving || _disposed || !['system', '简体中文', 'English'].contains(value)) {
      return;
    }
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await repository.saveQuestionLanguage(value);
      language = value;
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
