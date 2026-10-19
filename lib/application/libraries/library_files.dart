import '../ports/repositories.dart';

class LibraryScanEntry {
  const LibraryScanEntry.read(this.input) : error = null;
  const LibraryScanEntry.failed(String this.error) : input = null;
  final ImportInput? input;
  final String? error;
}

/// A library owns a directory; file access and SQL stay outside presentation.
abstract interface class LibraryFiles {
  String get directory;
  bool containsOrigin(String origin);
  Stream<LibraryScanEntry> scan();
  Future<ImportInput> store(ImportInput input);
}
