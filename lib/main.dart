import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/library_host.dart';
import 'infrastructure/persistence/library_catalog.dart';
import 'infrastructure/platform/library_files.dart';
import 'app/dependencies.dart';
import 'app/theme.dart';
import 'infrastructure/persistence/database.dart';
import 'l10n/localization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'OmniQuiz',
    ], await rootBundle.loadString('LICENSE'));
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
    final selected = catalog.selected;
    final studyDatabase = selected.legacy
        ? database
        : QuizDatabase(
            NativeDatabase.createInBackground(
              File(catalog.databasePath(selected)),
            ),
          );
    final dependencies = await AppDependencies.create(
      database: studyDatabase,
      settingsDatabase: database,
      ownsDatabase: !selected.legacy,
      libraryFiles: DirectoryLibraryFiles(selected.directory),
    );
    runApp(LibraryHost(catalog: catalog, initial: dependencies));
  } catch (_) {
    runApp(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(),
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
