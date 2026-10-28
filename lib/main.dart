// Bootstraps local databases, legal notices and the correct distribution update channel.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/library_host.dart';
import 'app/distribution.dart';
import 'infrastructure/persistence/library_catalog.dart';
import 'infrastructure/platform/library_files.dart';
import 'app/dependencies.dart';
import 'app/theme.dart';
import 'infrastructure/persistence/database.dart';
import 'l10n/localization.dart';
import 'infrastructure/updates/update_preferences.dart';
import 'presentation/updates/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'OmniQuiz',
    ], await rootBundle.loadString('LICENSE'));
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final database = QuizDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'omniquiz.sqlite')),
      ),
    );
    final catalog = LibraryCatalog(database, directory.path);
    await catalog.load();
    final selected = catalog.libraries.isEmpty ? null : catalog.selected;
    QuizDatabase studyDatabase;
    var unavailable = false;
    try {
      studyDatabase = selected == null
          ? QuizDatabase(NativeDatabase.memory())
          : await catalog.openLibrary(selected);
    } catch (_) {
      // An unplugged library must not prevent access to global settings or grants.
      unavailable = true;
      studyDatabase = QuizDatabase(NativeDatabase.memory());
    }
    final dependencies = await AppDependencies.create(
      database: studyDatabase,
      settingsDatabase: database,
      ownsDatabase: true,
      libraryFiles: selected == null || unavailable
          ? null
          : DirectoryLibraryFiles(selected.directory),
    );
    runApp(
      LibraryHost(
        catalog: catalog,
        initial: dependencies,
        initialUnavailable: unavailable,
        updates: microsoftStoreBuild
            ? null
            : UpdateController(SqlUpdatePreferences(database)),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SelectableText(context.l10n.startupError),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
