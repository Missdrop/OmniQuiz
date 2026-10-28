// Writes bounded, local status diagnostics without prompts, credentials or account data.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../application/generation/coordinator.dart';
import 'library_workspace.dart';

/// A failed log write never changes generation. Serialization prevents interleaved lines.
class GenerationLog {
  GenerationLog(this.workspace);
  final LibraryWorkspace workspace;
  Future<void> _pending = Future.value();
  void record(GenerationStatus status) {
    _pending = _pending
        .then((_) async {
          await workspace.ensure();
          final file = File(p.join(workspace.metadata, 'generation.log'));
          final previous = File('${file.path}.previous');
          await LibraryWorkspace.requireRegularFile(file.path);
          await LibraryWorkspace.requireRegularFile(previous.path);
          if (await file.exists() && await file.length() > 256 * 1024) {
            if (await previous.exists()) await previous.delete();
            await file.rename(previous.path);
          }
          await file.writeAsString(
            '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'stage': status.message, 'running': status.running, 'error': status.error})}\n',
            mode: FileMode.append,
            flush: true,
          );
        })
        .catchError((Object _) {});
  }

  Future<void> flush() => _pending;
}
