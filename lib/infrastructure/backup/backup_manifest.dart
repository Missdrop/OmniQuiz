import 'dart:convert';

import 'package:path/path.dart' as p;

/// Versioned, portable metadata. Paths in the archive and restored paths have
/// separate validation rules: neither can choose a destination outside the app.
class BackupManifest {
  const BackupManifest(this.libraries, {this.missingOriginals = 0});
  final List<BackupLibrary> libraries;
  final int missingOriginals;

  factory BackupManifest.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['format'] != 'omniquiz-backup' || json['version'] != 1) {
      throw const FormatException('Unsupported backup format');
    }
    final libraries = (json['libraries'] as List)
        .map((item) => BackupLibrary.fromJson(item))
        .toList();
    if (libraries.isEmpty || libraries.length > 100) {
      throw const FormatException('Invalid library count');
    }
    final manifest = BackupManifest(
      libraries,
      missingOriginals: json['missingOriginals'] as int? ?? 0,
    );
    final entries = manifest.entries.toList();
    if (entries.toSet().length != entries.length) {
      throw const FormatException('Duplicate backup entry');
    }
    return manifest;
  }

  Iterable<String> get entries sync* {
    yield 'manifest.json';
    for (final library in libraries) {
      yield library.database;
      yield* library.files.map((file) => file.entry);
    }
  }

  String encode() => jsonEncode({
    'format': 'omniquiz-backup',
    'version': 1,
    'libraries': libraries.map((library) => library.toJson()).toList(),
    'missingOriginals': missingOriginals,
  });
}

class BackupLibrary {
  const BackupLibrary({
    required this.name,
    required this.database,
    required this.files,
  });
  final String name, database;
  final List<BackupMaterial> files;

  factory BackupLibrary.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final database = json['database'] as String;
    if (name.isEmpty ||
        name.length > 80 ||
        !RegExp(r'^libraries/[0-9a-f-]{36}/database\.sqlite$')
            .hasMatch(database)) {
      throw const FormatException('Invalid library metadata');
    }
    final files = (json['files'] as List)
        .map((item) => BackupMaterial.fromJson(item))
        .toList();
    final prefix = database.substring(0, database.lastIndexOf('/'));
    if (files.any((file) => !file.entry.startsWith('$prefix/files/')) ||
        files.map((file) => file.path.toLowerCase()).toSet().length !=
            files.length ||
        files.map((file) => file.origin).toSet().length != files.length) {
      throw const FormatException('Invalid material mapping');
    }
    return BackupLibrary(name: name, database: database, files: files);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'database': database,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

class BackupMaterial {
  const BackupMaterial({
    required this.entry,
    required this.path,
    required this.origin,
  });
  final String entry, path, origin;

  factory BackupMaterial.fromJson(Map<String, dynamic> json) {
    final entry = json['entry'] as String;
    final path = json['path'] as String;
    if (!RegExp(r'^libraries/[0-9a-f-]{36}/files/[0-9a-f-]{36}$')
            .hasMatch(entry) ||
        p.posix.isAbsolute(path) ||
        p.windows.isAbsolute(path) ||
        path.contains('\\') ||
        path
            .split('/')
            .any(
              (part) =>
                  part.isEmpty ||
                  part == '.' ||
                  part == '..' ||
                  RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(part),
            )) {
      throw const FormatException('Invalid material path');
    }
    return BackupMaterial(
      entry: entry,
      path: path,
      origin: json['origin'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'entry': entry,
    'path': path,
    'origin': origin,
  };
}
