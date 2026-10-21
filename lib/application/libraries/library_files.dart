import '../ports/repositories.dart';
import 'scan_state.dart';

class LibraryScanEntry {
  const LibraryScanEntry.read(this.input, {this.stamp}) : error = null;
  const LibraryScanEntry.skipped(this.stamp) : input = null, error = null;
  const LibraryScanEntry.failed(String this.error, {this.stamp}) : input = null;
  final FileStamp? stamp;
  final ImportInput? input;
  final String? error;
}

/// A library owns a directory; file access and SQL stay outside presentation.
abstract interface class LibraryFiles {
  String get directory;
  bool containsOrigin(String origin);
  Stream<LibraryScanEntry> scan({
    bool Function(FileStamp)? skip,
    bool Function()? cancelled,
  });
  Future<ImportInput> store(
    ImportInput input, {
    bool preserveDirectories = false,
  });
}
