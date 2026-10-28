// Defines library file operations independently of storage adapters and import presentation.

import '../ports/repositories.dart';
import 'scan_state.dart';

/// One read, skipped or failed filesystem entry from a cancellable scan.
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
  /// Canonical root that owns imported copies, not necessarily the original sources.
  String get directory;

  /// Checks whether an origin can be managed safely by this library adapter.
  bool containsOrigin(String origin);

  /// Metadata hints may skip verified files; cancellation stops future filesystem reads.
  Stream<LibraryScanEntry> scan({
    bool Function(FileStamp)? skip,
    bool Function()? cancelled,
  });

  /// Copies idempotently; colliding names with different contents must not overwrite.
  Future<ImportInput> store(
    ImportInput input, {
    bool preserveDirectories = false,
  });
}
