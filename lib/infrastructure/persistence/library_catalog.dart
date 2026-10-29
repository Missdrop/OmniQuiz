// Stores workspace identities and selected library outside user-managed material directories.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;

import '../../domain/study_library.dart';
import 'database.dart';
import 'library_workspace.dart';
import '../backup/backup_database.dart';
import 'scan_state_store.dart';
import '../../application/libraries/scan_state.dart';
import '../../domain/models.dart';

/// Stored beside global preferences, never inside user-owned material folders.
class LibraryCatalog {
  LibraryCatalog(this.database, this.root);
  final QuizDatabase database;
  final String root;
  List<StudyLibrary> libraries = [];
  String selectedId = '';

  Future<void> load() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='libraries'")
        .getSingleOrNull();
    if (row == null) {
      libraries = [];
      selectedId = '';
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
      if (!libraries.any((item) => item.id == selectedId)) {
        selectedId = libraries.firstOrNull?.id ?? '';
      }
    }
  }

  StudyLibrary get selected =>
      libraries.firstWhere((item) => item.id == selectedId);
  String legacyDatabasePath(StudyLibrary library) => library.legacy
      ? p.join(root, 'omniquiz.sqlite')
      : p.join(root, 'libraries', library.id, 'quiz.sqlite');
  String databasePath(StudyLibrary library) =>
      LibraryWorkspace(library.directory).databasePath;

  /// Copy a consistent snapshot once; keep the old file as migration recovery.
  /// The portable DB thereafter wins, including when its folder is reattached.
  Future<QuizDatabase> openLibrary(StudyLibrary library) async {
    final workspace = LibraryWorkspace(library.directory);
    await workspace.ensure();
    final target = File(databasePath(library));
    final previous = File(legacyDatabasePath(library));
    if (!await target.exists() && await previous.exists()) {
      final migrated = await database
          .customSelect(
            'SELECT value FROM settings WHERE key=?',
            variables: [Variable('portable:${library.id}')],
          )
          .getSingleOrNull();
      // Deleting a portable DB later is not consent to resurrect an obsolete copy.
      if (migrated == null) {
        final source = library.legacy
            ? database
            : QuizDatabase(NativeDatabase.createInBackground(previous));
        final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
        try {
          await BackupDatabase.snapshot(source, temporary.path);
          BackupDatabase.validate(temporary.path);
          await temporary.rename(target.path);
        } finally {
          if (!library.legacy) await source.close();
          if (await temporary.exists()) await temporary.delete();
        }
      }
    }
    final opened = QuizDatabase(NativeDatabase.createInBackground(target));
    try {
      await _rebaseMovedFolder(opened, library.directory);
      await database.customStatement(
        "INSERT OR REPLACE INTO settings VALUES (?, '1')",
        ['portable:${library.id}'],
      );
      return opened;
    } catch (_) {
      await opened.close();
      rethrow;
    }
  }

  /// Preserve document IDs/history when the whole portable folder changes location.
  /// Original paths outside the old library stay untouched.
  Future<void> _rebaseMovedFolder(QuizDatabase db, String directory) =>
      db.transaction(() async {
        final record = await db
            .customSelect("SELECT value FROM settings WHERE key='library_root'")
            .getSingleOrNull();
        final previous = record?.read<String>('value');
        if (previous != null && previous != directory) {
          final oldPaths = p.Context(
            style: previous.contains('\\') ? p.Style.windows : p.Style.posix,
          );
          String rebase(String origin) => oldPaths.isWithin(previous, origin)
              ? p.join(
                  directory,
                  p.joinAll(
                    oldPaths.split(oldPaths.relative(origin, from: previous)),
                  ),
                )
              : origin;
          for (final row
              in await db
                  .customSelect('SELECT id,origin FROM documents')
                  .get()) {
            await db.customStatement(
              'UPDATE documents SET origin=? WHERE id=?',
              [rebase(row.read<String>('origin')), row.read<String>('id')],
            );
          }
          final scans = SqlScanStateStore(db);
          final records = await scans.load();
          await scans.save({
            for (final entry in records.entries)
              rebase(entry.key): ScanRecord(
                name: entry.value.name,
                ignored: entry.value.ignored,
              ),
          });
          await db.invalidateGeneration();
        }
        await db.customStatement(
          "INSERT OR REPLACE INTO settings VALUES ('library_root',?)",
          [directory],
        );
      });

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
    await LibraryWorkspace(item.directory).ensure();
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

  /// Call only after closing this library's session. Stage the exact registered target
  /// before changing the catalog, so a failed catalog write can restore the folder.
  Future<void> remove(StudyLibrary library, {bool keepMaterials = true}) async {
    final registered = libraries
        .where((item) => item.id == library.id)
        .firstOrNull;
    if (registered == null) throw ArgumentError('Unknown library');
    var folder = p.normalize(p.absolute(registered.directory));
    final type = await FileSystemEntity.type(folder, followLinks: false);
    Directory? staged;
    String? target;
    if (type != FileSystemEntityType.notFound) {
      if (type != FileSystemEntityType.directory) {
        throw const AppFailure('Library deletion target is unsafe.');
      }
      final resolved = p.normalize(
        await Directory(folder).resolveSymbolicLinks(),
      );
      final settings = p.normalize(
        await Directory(root).resolveSymbolicLinks(),
      );
      final logicalSettings = p.normalize(p.absolute(root));
      // Android exposes app-private storage through both /data/data and /data/user/0.
      // Accept that alias only for the same relative path inside our private root.
      final internalAlias =
          p.isWithin(logicalSettings, folder) &&
          p.isWithin(settings, resolved) &&
          p.equals(
            p.relative(folder, from: logicalSettings),
            p.relative(resolved, from: settings),
          );
      if (!p.equals(folder, resolved) && !internalAlias) {
        throw const AppFailure('Library deletion target is unsafe.');
      }
      folder = resolved;
      if (!keepMaterials) {
        if (p.equals(folder, p.dirname(folder)) ||
            p.equals(folder, settings) ||
            p.isWithin(folder, settings) ||
            libraries.any(
              (other) =>
                  other.id != registered.id &&
                  (p.equals(folder, p.normalize(p.absolute(other.directory))) ||
                      p.isWithin(
                        folder,
                        p.normalize(p.absolute(other.directory)),
                      )),
            )) {
          throw const AppFailure('Library deletion target is unsafe.');
        }
      }
      await LibraryWorkspace(registered.directory).ensureForDeletion();
      target = keepMaterials ? LibraryWorkspace(folder).metadata : folder;
      final targetType = await FileSystemEntity.type(
        target,
        followLinks: false,
      );
      if (targetType != FileSystemEntityType.notFound) {
        if (targetType != FileSystemEntityType.directory) {
          throw const AppFailure('Library deletion target is unsafe.');
        }
        if (!p.equals(
          p.normalize(target),
          p.normalize(await Directory(target).resolveSymbolicLinks()),
        )) {
          throw const AppFailure('Library deletion target is unsafe.');
        }
        // Resolve and bound both paths before any rename or recursive deletion.
        final parent = await Directory(p.dirname(target))
            .resolveSymbolicLinks();
        final destination = p.join(
          parent,
          '.omniquiz-delete-${const Uuid().v4()}',
        );
        if (!p.equals(p.normalize(p.dirname(target)), p.normalize(parent)) ||
            !p.isWithin(parent, destination)) {
          throw const AppFailure('Library deletion target is unsafe.');
        }
        staged = await Directory(target).rename(destination);
      }
    }
    final next = libraries.where((item) => item.id != registered.id).toList();
    final selection = selectedId == registered.id
        ? next.firstOrNull?.id ?? ''
        : selectedId;
    try {
      await _save(next, selection);
    } catch (_) {
      if (staged != null) await staged.rename(target!);
      rethrow;
    }
    libraries = next;
    selectedId = selection;
    if (staged != null) {
      try {
        final resolved = p.normalize(await staged.resolveSymbolicLinks());
        if (!p.equals(resolved, p.normalize(staged.absolute.path))) {
          throw const AppFailure('Library deletion target is unsafe.');
        }
        await staged.delete(recursive: true);
      } catch (_) {
        throw const AppFailure(
          'Library removed, but some study data could not be deleted.',
        );
      }
    }
  }

  Future<void> addRestored(List<StudyLibrary> restored) async {
    final next = [...libraries, ...restored];
    await _save(next, selectedId);
    libraries = next;
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
