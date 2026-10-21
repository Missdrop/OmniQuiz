import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../platform/zip_document_access.dart';
import 'backup_manifest.dart';

/// Archive I/O only: no live database or library catalog is accessible here.
class BackupArchive {
  static const maxArchiveBytes = 100 * 1024 * 1024;
  static const maxExpandedBytes = 512 * 1024 * 1024;
  static const maxEntries = 10000;
  static final _allowed = RegExp(
    r'^(manifest\.json|libraries/[0-9a-f-]{36}/(database\.sqlite|files/[0-9a-f-]{36}))$',
  );

  static void pack(String stage, String output) {
    final encoder = ZipFileEncoder()..create(output);
    try {
      for (final entry in Directory(
        stage,
      ).listSync(recursive: true, followLinks: false)) {
        if (entry is File) {
          encoder.addFileSync(
            entry,
            p.relative(entry.path, from: stage).replaceAll('\\', '/'),
          );
        }
      }
    } finally {
      encoder.closeSync();
    }
  }

  static BackupManifest unpack(String input, String stage) {
    final stream = InputFileStream(input);
    try {
      ZipDocumentAccess.checkDirectoryBudget(stream, maxEntryCount: maxEntries);
      final headers = (ZipDirectory()..read(stream)).fileHeaders;
      final names = _validateHeaders(headers);
      for (final header in headers) {
        _extract(header, stage);
      }
      final manifest = BackupManifest.decode(
        File(p.join(stage, 'manifest.json')).readAsStringSync(),
      );
      if (manifest.entries.toSet().difference(names).isNotEmpty ||
          manifest.entries.length != names.length) {
        throw const FormatException('Backup content does not match manifest');
      }
      return manifest;
    } finally {
      stream.closeSync();
    }
  }

  static Set<String> _validateHeaders(List<ZipFileHeader> headers) {
    if (headers.isEmpty || headers.length > maxEntries) {
      throw const FormatException('Invalid backup count');
    }
    final seen = <String>{};
    var total = 0;
    for (final header in headers) {
      total += header.uncompressedSize;
      final name = header.filename;
      final limit = name.endsWith('.sqlite')
          ? 128 * 1024 * 1024
          : name == 'manifest.json'
          ? 1024 * 1024
          : 20 * 1024 * 1024;
      if (!_allowed.hasMatch(name) ||
          !seen.add(name) ||
          header.file?.filename != name ||
          header.uncompressedSize != header.file?.uncompressedSize ||
          header.uncompressedSize < 0 ||
          header.uncompressedSize > limit ||
          total > maxExpandedBytes ||
          (header.generalPurposeBitFlag & 1) != 0 ||
          ![0, 8].contains(header.compressionMethod) ||
          ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const FormatException('Unsafe backup entry');
      }
    }
    return seen;
  }

  static void _extract(ZipFileHeader header, String stage) {
    final target = File(p.join(stage, header.filename));
    target.parent.createSync(recursive: true);
    final output = OutputFileStream(target.path);
    try {
      header.file!.decompress(output);
    } finally {
      output.closeSync();
    }
    if (target.lengthSync() != header.uncompressedSize ||
        _crc(target) != header.crc32) {
      throw const FormatException('Damaged backup entry');
    }
  }

  static int _crc(File file) {
    final input = file.openSync();
    final buffer = Uint8List(64 * 1024);
    var crc = 0;
    try {
      while (true) {
        final count = input.readIntoSync(buffer);
        if (count == 0) return crc;
        crc = getCrc32(Uint8List.sublistView(buffer, 0, count), crc);
      }
    } finally {
      input.closeSync();
    }
  }
}
