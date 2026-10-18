import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'app/theme.dart';
import 'infrastructure/persistence/database.dart';

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
    final dependencies = await AppDependencies.create(database: database);
    runApp(OmniQuizApp(dependencies: dependencies));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: SelectableText(
                'OmniQuiz could not open local storage. Check available disk space and application permissions, then restart.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
