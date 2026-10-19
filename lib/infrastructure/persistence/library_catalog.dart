import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/study_library.dart';
import 'database.dart';

/// Stored beside global preferences, never inside user-owned material folders.
class LibraryCatalog {
  LibraryCatalog(this.database, this.root);
  final QuizDatabase database;
  final String root;
  List<StudyLibrary> libraries = [];
  String selectedId = 'default';

  Future<void> load() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='libraries'")
        .getSingleOrNull();
    if (row == null) {
      final directory = p.join(root, 'libraries', 'default', 'materials');
      await Directory(directory).create(recursive: true);
      libraries = [
        StudyLibrary(id: 'default', name: 'Default', directory: directory),
      ];
      await _save(libraries, selectedId);
    } else {
      final data =
          jsonDecode(row.read<String>('value')) as Map<String, dynamic>;
      libraries = (data['items'] as List)
          .map(
            (item) => StudyLibrary(
              id: item['id'] as String,
              name: item['name'] as String,
              directory: item['directory'] as String,
            ),
          )
          .toList();
      selectedId = data['selected'] as String;
    }
  }

  StudyLibrary get selected =>
      libraries.firstWhere((item) => item.id == selectedId);
  String databasePath(StudyLibrary library) => library.legacy
      ? p.join(root, 'omniquiz.sqlite')
      : p.join(root, 'libraries', library.id, 'quiz.sqlite');

  Future<StudyLibrary> create(String name, {String? directory}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException('Enter a library name (1–80 characters).');
    }
    final id = const Uuid().v4();
    final folder = directory == null
        ? p.join(root, 'libraries', id, 'materials')
        : await Directory(directory).resolveSymbolicLinks();
    if (directory == null) await Directory(folder).create(recursive: true);
    // Overlapping roots make one library's imports appear in another library.
    for (final library in libraries) {
      final existing = p.normalize(p.absolute(library.directory));
      final candidate = p.normalize(p.absolute(folder));
      if (p.equals(existing, candidate) ||
          p.isWithin(existing, candidate) ||
          p.isWithin(candidate, existing)) {
        throw const FormatException(
          'Choose a separate folder for each library.',
        );
      }
    }
    final item = StudyLibrary(id: id, name: trimmed, directory: folder);
    await Directory(p.dirname(databasePath(item))).create(recursive: true);
    final next = [...libraries, item];
    await _save(next, selectedId);
    libraries = next;
    return item;
  }

  Future<void> select(StudyLibrary library) async {
    if (!libraries.any((item) => item.id == library.id)) {
      throw ArgumentError('Unknown library');
    }
    await _save(libraries, library.id);
    selectedId = library.id;
  }

  Future<void> _save(List<StudyLibrary> items, String selected) =>
      database.customStatement(
        "INSERT OR REPLACE INTO settings VALUES ('libraries', ?)",
        [
          jsonEncode({
            'selected': selected,
            'items': [
              for (final item in items)
                {'id': item.id, 'name': item.name, 'directory': item.directory},
            ],
          }),
        ],
      );
}
