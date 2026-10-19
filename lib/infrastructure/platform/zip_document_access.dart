import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';
import 'document_access.dart';

/// Decompresses and verifies in a worker, then reads one material at a time.
/// Nothing reaches a library until the whole archive has passed validation.
class ZipDocumentAccess implements ArchiveAccess {
  static const maxArchiveBytes = 100 * 1024 * 1024;
  static const maxExpandedBytes = 100 * 1024 * 1024;
  static const maxEntries = 1000;

  @override
  Stream<ImportInput> pickZip() async* {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (selected == null) return;
    if (selected.path == null) {
      throw const AppFailure('The selected ZIP could not be read.');
    }
    yield* read(selected.path!);
  }

  Stream<ImportInput> read(String path) async* {
    if (await File(path).length() > maxArchiveBytes) {
      throw const AppFailure('ZIP exceeds the 100 MB archive limit.');
    }
    final temporary = await Directory.systemTemp.createTemp('omniquiz-zip-');
    try {
      final names = await Isolate.run(() => _extract(path, temporary.path));
      for (final name in names) {
        yield ImportInput(
          name: name,
          origin: 'zip:$name',
          bytes: await File(p.join(temporary.path, p.joinAll(name.split('/'))))
              .readAsBytes(),
        );
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Could not read this ZIP. Use an unencrypted ZIP with standard compression.',
      );
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  static List<String> _extract(String path, String destination) {
    final input = InputFileStream(path);
    try {
      _checkDirectoryBudget(input);
      final directory = ZipDirectory()..read(input);
      if (directory.fileHeaders.length > maxEntries) {
        throw const AppFailure(
          'ZIP contains more than 1000 entries. Split the archive.',
        );
      }
      final selected = <(ZipFileHeader, String)>[];
      final seen = <String>{};
      var expanded = 0;
      // Inspect all paths and sizes before decompressing even the first entry.
      for (final header in directory.fileHeaders) {
        final file = header.file!;
        final name = header.filename.replaceAll('\\', '/');
        final parts = name.split('/');
        final isDirectory = name.endsWith('/');
        if (p.posix.isAbsolute(name) ||
            p.windows.isAbsolute(name) ||
            parts.any(
              (part) =>
                  part == '..' ||
                  part == '.' ||
                  RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(part),
            ) ||
            name != file.filename.replaceAll('\\', '/') ||
            ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
          throw const AppFailure(
            'ZIP contains unsafe paths or links. Nothing was imported.',
          );
        }
        if ((header.generalPurposeBitFlag & 1) != 0 ||
            (file.flags & 1) != 0 ||
            ![0, 8].contains(header.compressionMethod)) {
          throw const AppFailure(
            'Could not read this ZIP. Use an unencrypted ZIP with standard compression.',
          );
        }
        if (header.uncompressedSize != file.uncompressedSize ||
            header.uncompressedSize < 0) {
          throw const AppFailure('ZIP contains invalid file sizes.');
        }
        expanded += header.uncompressedSize;
        if (expanded > maxExpandedBytes) {
          throw const AppFailure('ZIP expands beyond the 100 MB limit.');
        }
        if (isDirectory ||
            parts.any((part) => part.startsWith('.') || part == '__MACOSX')) {
          continue;
        }
        if (parts.any(
              (part) =>
                  part.isEmpty || part.endsWith('.') || part.endsWith(' '),
            ) ||
            !seen.add(name.toLowerCase())) {
          throw const AppFailure(
            'ZIP contains unsafe or duplicate file paths.',
          );
        }
        if (!PlatformDocumentAccess.extensions.contains(
          p.posix.extension(name).replaceFirst('.', '').toLowerCase(),
        )) {
          continue;
        }
        if (header.uncompressedSize > PlatformDocumentAccess.maxBytes) {
          throw const AppFailure(
            'A material in the ZIP exceeds the 20 MB file limit.',
          );
        }
        selected.add((header, name));
      }
      if (selected.isEmpty) {
        throw const AppFailure(
          'No supported materials in ZIP. Include TXT, Markdown or text PDF.',
        );
      }
      for (final (header, name) in selected) {
        final target = File(p.join(destination, p.joinAll(name.split('/'))));
        target.parent.createSync(recursive: true);
        final output = OutputFileStream(target.path);
        try {
          header.file!.decompress(output);
        } finally {
          output.closeSync();
        }
        final bytes = target.readAsBytesSync();
        if (bytes.length != header.uncompressedSize ||
            getCrc32(bytes) != header.crc32) {
          throw const AppFailure('ZIP is damaged. Nothing was imported.');
        }
      }
      return [for (final item in selected) item.$2];
    } finally {
      input.closeSync();
    }
  }

  static void _checkDirectoryBudget(InputFileStream input) {
    // ZIP64 is unnecessary within these limits. Check EOCD before the archive
    // library allocates an object for every central-directory entry.
    final tail = input
        .subset(position: (input.length - 65557).clamp(0, input.length))
        .toUint8List();
    final data = ByteData.sublistView(tail);
    for (var i = tail.length - 22; i >= 0; i--) {
      if (data.getUint32(i, Endian.little) != 0x06054b50 ||
          i + 22 + data.getUint16(i + 20, Endian.little) != tail.length) {
        continue;
      }
      if (data.getUint16(i + 10, Endian.little) > maxEntries ||
          data.getUint32(i + 12, Endian.little) > 8 * 1024 * 1024) {
        throw const AppFailure(
          'ZIP contains more than 1000 entries. Split the archive.',
        );
      }
      if (data.getUint16(i + 4, Endian.little) != 0 ||
          data.getUint16(i + 6, Endian.little) != 0) {
        throw const AppFailure(
          'Could not read this ZIP. Use an unencrypted ZIP with standard compression.',
        );
      }
      return;
    }
    throw const AppFailure('ZIP is damaged. Nothing was imported.');
  }
}
