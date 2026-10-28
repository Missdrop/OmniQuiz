// Reads editable authoring files on every batch; SQL is a recoverable backup/cache.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../application/ports/repositories.dart';
import '../../domain/generation_guidance.dart';
import '../../domain/models.dart';
import '../../domain/policies.dart';
import 'generation_guidance_repository.dart';
import 'library_workspace.dart';

/// Swaps a complete guidance folder on Save. Reads never overwrite external edits.
/// A retained previous directory recovers an interrupted rename on the next open.
class FileGenerationGuidanceRepository
    implements GenerationGuidanceRepository, GenerationBufferRepository {
  FileGenerationGuidanceRepository(this.workspace, this.cache, this.parser);
  final LibraryWorkspace workspace;
  final SqlGenerationGuidanceRepository cache;
  final DocumentParser parser;
  final Map<String, String> _paths = {};
  String get _root => workspace.guidancePath;
  String get _previous => p.join(workspace.metadata, '.guidance-previous');

  Future<GenerationGuidance> _bufferSettings() async {
    final text = await _text(p.join(_root, 'settings.json'), 4096);
    return text.isEmpty
        ? GenerationGuidance()
        : GenerationGuidance.fromJson(
            Map<String, dynamic>.from(jsonDecode(text) as Map),
          );
  }

  @override
  Future<BufferPolicy> loadBufferPolicy() async {
    await _recover();
    final settings = await Directory(_root).exists()
        ? await _bufferSettings()
        : await cache.load();
    return BufferPolicy(
      low: settings.refillThreshold,
      batchSize: settings.questionsPerBatch,
    );
  }

  Future<void> _recover() async {
    await workspace.ensure();
    for (final path in [_root, _previous]) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const AppFailure('Library metadata contains an unsafe path.');
      }
    }
    if (!await Directory(_root).exists() &&
        await Directory(_previous).exists()) {
      await Directory(_previous).rename(_root);
    }
  }

  @override
  Future<GenerationGuidance> load() async {
    await _recover();
    if (!await Directory(_root).exists()) {
      // Upgrade extracted-only drafts once. Future requests read the files.
      await save(await cache.load());
    }
    final requirements = await _text(
      p.join(_root, 'requirements.md'),
      GenerationGuidance.requirementsLimit * 4,
    );
    final pasted = await _text(
      p.join(_root, 'pasted-example.md'),
      GenerationGuidance.pastedLimit * 4,
    );
    final settings = await _bufferSettings();
    final examples = <ReferenceExample>[];
    final examplesPath = p.join(_root, 'examples');
    await LibraryWorkspace.ensureDirectory(examplesPath);
    _paths.clear();
    final files = await _files(Directory(examplesPath)).toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      if (!parser.supports(file.path)) continue;
      if (examples.length >= GenerationGuidance.exampleCountLimit) {
        throw const AppFailure('Question guidance exceeds its size limits.');
      }
      if (await file.length() > 20 * 1024 * 1024) {
        throw const AppFailure('File exceeds 20 MB.');
      }
      final bytes = await file.readAsBytes();
      final sections = await parser.parse(
        ImportInput(
          name: p.basename(file.path),
          origin: file.path,
          bytes: bytes,
        ),
      );
      final text = sections
          .map((s) => '[${s.location}]\n${s.text.trim()}')
          .join('\n\n')
          .trim();
      final id = sha256.convert(utf8.encode(text)).toString();
      if (examples.any((e) => e.id == id)) continue;
      _paths[id] = file.path;
      examples.add(
        ReferenceExample(
          id: id,
          name: p.relative(file.path, from: examplesPath),
          text: text,
        ),
      );
      GenerationGuidance(
        requirements: requirements,
        pastedExample: pasted,
        examples: examples,
      );
    }
    final value = GenerationGuidance(
      requirements: requirements,
      pastedExample: pasted,
      examples: examples,
      questionsPerBatch: settings.questionsPerBatch,
      refillThreshold: settings.refillThreshold,
    );
    // External edits invalidate pending work, but never discard cached questions.
    await cache.save(value);
    return value;
  }

  Future<String> _text(String path, int limit) async {
    await LibraryWorkspace.requireRegularFile(path);
    final file = File(path);
    if (!await file.exists()) return '';
    if (await file.length() > limit) {
      throw const AppFailure('Question guidance exceeds its size limits.');
    }
    return (await file.readAsString()).replaceFirst('\uFEFF', '').trim();
  }

  Stream<File> _files(Directory directory, [int depth = 0]) async* {
    if (depth > 8) {
      throw const AppFailure('Question guidance exceeds its size limits.');
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (p.basename(entity.path).startsWith('.')) continue;
      if (entity is Link) {
        throw const AppFailure('Library metadata contains an unsafe path.');
      }
      if (entity is File) yield entity;
      if (entity is Directory) yield* _files(entity, depth + 1);
    }
  }

  @override
  Future<void> save(GenerationGuidance value) async {
    await _recover();
    final stage = await Directory(
      p.join(workspace.metadata, '.guidance-${const Uuid().v4()}'),
    ).create();
    var installed = false;
    try {
      await File(p.join(stage.path, 'requirements.md'))
          .writeAsString(value.requirements, flush: true);
      await File(p.join(stage.path, 'pasted-example.md'))
          .writeAsString(value.pastedExample, flush: true);
      await File(p.join(stage.path, 'settings.json')).writeAsString(
        jsonEncode({
          'questionsPerBatch': value.questionsPerBatch,
          'refillThreshold': value.refillThreshold,
        }),
        flush: true,
      );
      final examples = await Directory(p.join(stage.path, 'examples')).create();
      final names = <String>{};
      final nextPaths = <String, String>{};
      for (final sample in value.examples) {
        final previous = _paths[sample.id];
        var name = p
            .basename(sample.name)
            .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
        List<int> bytes;
        if (sample.originalBytes != null) {
          bytes = sample.originalBytes!;
        } else if (previous != null && await File(previous).exists()) {
          await LibraryWorkspace.requireRegularFile(previous);
          bytes = await File(previous).readAsBytes();
        } else {
          // Legacy drafts have no original PDF bytes: preserve their extracted text honestly.
          name = '${p.basenameWithoutExtension(name)}.md';
          bytes = utf8.encode(sample.text);
        }
        if (bytes.length > 20 * 1024 * 1024) {
          throw const AppFailure('File exceeds 20 MB.');
        }
        if (!names.add(name.toLowerCase())) {
          name =
              '${sample.id.substring(0, sample.id.length.clamp(0, 12))}-$name';
          if (!names.add(name.toLowerCase())) {
            throw const AppFailure('Invalid or duplicate reference examples.');
          }
        }
        await File(p.join(examples.path, name))
            .writeAsBytes(bytes, flush: true);
        nextPaths[sample.id] = p.join(_root, 'examples', name);
      }
      if (await Directory(_previous).exists()) {
        await Directory(_previous).delete(recursive: true);
      }
      if (await Directory(_root).exists()) {
        await Directory(_root).rename(_previous);
      }
      await stage.rename(_root);
      installed = true;
      try {
        await cache.save(value);
      } catch (_) {
        await Directory(_root).delete(recursive: true);
        if (await Directory(_previous).exists()) {
          await Directory(_previous).rename(_root);
        }
        rethrow;
      }
      // Preserve the original-file mapping for subsequent edits in this session.
      _paths
        ..clear()
        ..addAll(nextPaths);
      if (await Directory(_previous).exists()) {
        await Directory(_previous).delete(recursive: true);
      }
    } finally {
      if (!installed && await stage.exists()) {
        await stage.delete(recursive: true);
      }
      if (!await Directory(_root).exists() &&
          await Directory(_previous).exists()) {
        await Directory(_previous).rename(_root);
      }
    }
  }
}
