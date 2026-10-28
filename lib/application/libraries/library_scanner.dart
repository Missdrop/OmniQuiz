// Uses metadata hints and explicit exclusions to scan incrementally without deleting original files.

import '../../domain/models.dart';
import '../ports/repositories.dart';
import '../use_cases/import_materials.dart';
import 'library_files.dart';
import 'scan_state.dart';

/// Cooperative cancellation shared across scanner and file iteration.
class ScanCancellation {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

/// A lightweight checked-file count and current path for progress presentation.
class ScanProgress {
  const ScanProgress(this.checked, this.name);
  final int checked;
  final String name;
}

/// Summarizes completed imports, exclusions, failures and missing originals.
class ScanResult {
  const ScanResult(
    this.imported,
    this.unchanged,
    this.ignored,
    this.missing,
    this.errors,
    this.cancelled,
  );
  final int imported, unchanged, ignored;
  final Set<String> missing;
  final List<String> errors;
  final bool cancelled;
}

/// Coordinates metadata hints, imports and exclusions without deleting sources
/// or treating an absent file as permission to discard a user's learning data.
class LibraryScanner {
  LibraryScanner(this.files, this.materials, this.importer, this.state);
  final LibraryFiles files;
  final MaterialRepository materials;
  final ImportMaterials importer;
  final ScanStateStore state;

  Future<Map<String, String>> exclusions() async => {
    for (final item in (await state.load()).entries)
      if (item.value.ignored) item.key: item.value.name,
  };

  Future<void> exclude(StudyDocument document) async {
    final records = await state.load();
    records[document.origin] = ScanRecord(name: document.name, ignored: true);
    // Persist intent first: even if removal fails, a later scan cannot reimport.
    await state.save(records);
    await materials.removeDocument(document.id);
  }

  Future<void> include(String origin) async {
    final records = await state.load();
    if (records.remove(origin) != null) await state.save(records);
  }

  Future<ScanResult> scan({
    bool full = false,
    required void Function(ScanProgress) onProgress,
    required ScanCancellation cancellation,
  }) async {
    final records = await state.load();
    final documents = {
      for (final d in await materials.documents()) d.origin: d,
    };
    final seen = <String>{};
    final errors = <String>[];
    var imported = 0, unchanged = 0, ignored = 0, checked = 0;
    try {
      await for (final entry in files.scan(
        cancelled: () => cancellation.cancelled,
        skip: (stamp) {
          final record = records[stamp.origin];
          final document = documents[stamp.origin];
          return record?.ignored == true ||
              (!full &&
                  document != null &&
                  record?.matches(stamp, document.revision) == true);
        },
      )) {
        if (cancellation.cancelled) break;
        final stamp = entry.stamp;
        if (stamp != null) seen.add(stamp.origin);
        if (entry.input != null) seen.add(entry.input!.origin);
        onProgress(
          ScanProgress(++checked, stamp?.name ?? entry.input?.name ?? ''),
        );
        if (cancellation.cancelled) break;
        if (entry.error != null) {
          errors.add(entry.error!);
          continue;
        }
        if (entry.input == null) {
          if (records[stamp!.origin]?.ignored == true) {
            ignored++;
          } else {
            unchanged++;
          }
          continue;
        }
        final result = await importer.execute([entry.input!]);
        imported += result.imported;
        unchanged += result.unchanged;
        errors.addAll(result.errors);
        // Cache only successful imports. Parse failures must be retried.
        if (stamp != null && result.errors.isEmpty) {
          final doc = await materials.byOrigin(stamp.origin);
          records[stamp.origin] = ScanRecord(
            name: stamp.name,
            size: stamp.size,
            modified: stamp.modified,
            revision: doc!.revision,
          );
        }
      }
    } finally {
      // A cancellation keeps completed imports and never reconciles absence.
      await state.save(records);
    }
    return ScanResult(
      imported,
      unchanged,
      ignored,
      cancellation.cancelled || errors.isNotEmpty
          ? {}
          : {
              for (final origin in documents.keys)
                if (files.containsOrigin(origin) && !seen.contains(origin))
                  origin,
            },
      errors,
      cancellation.cancelled,
    );
  }
}
