// Extracts readable text from supported formats; parsing is separate from document publication.

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';

/// Parses UTF-8 text/Markdown outside the UI isolate.
class TextDocumentParser implements DocumentParser {
  @override
  bool supports(String filename) =>
      RegExp(r'\.(txt|md|markdown)$', caseSensitive: false).hasMatch(filename);
  @override
  Future<List<ParsedSection>> parse(ImportInput input) => Isolate.run(() {
    try {
      final text = utf8
          .decode(input.bytes)
          .replaceAll('\r\n', '\n')
          .replaceAll('\uFEFF', '');
      return [ParsedSection('Text', text)];
    } on FormatException {
      throw const AppFailure('Text files must use UTF-8 encoding.');
    }
  });
}

/// Extracts page text and releases the native PDF handle even when parsing fails.
class PdfDocumentParser implements DocumentParser {
  @override
  bool supports(String filename) => filename.toLowerCase().endsWith('.pdf');
  @override
  Future<List<ParsedSection>> parse(ImportInput input) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      Uint8List.fromList(input.bytes),
    );
    try {
      final sections = <ParsedSection>[];
      var total = 0;
      for (final page in document.pages) {
        final text = (await page.loadText())?.fullText ?? '';
        total += text.length;
        if (total > 1000000) {
          throw const AppFailure(
            'This document is too large. Split it into smaller files.',
          );
        }
        if (text.trim().isNotEmpty) {
          sections.add(ParsedSection('Page ${page.pageNumber}', text));
        }
      }
      if (sections.isEmpty) {
        throw const AppFailure(
          'No text found. Scanned PDFs need OCR before import.',
        );
      }
      return sections;
    } finally {
      await document.dispose();
    }
  }
}

/// Dispatches supported formats through one consistent parsing contract.
class ParserRegistry implements DocumentParser {
  ParserRegistry(this.parsers);
  final List<DocumentParser> parsers;
  @override
  bool supports(String filename) => parsers.any((p) => p.supports(filename));
  @override
  Future<List<ParsedSection>> parse(ImportInput input) {
    for (final parser in parsers) {
      if (parser.supports(input.name)) return parser.parse(input);
    }
    throw const AppFailure(
      'Supported formats: TXT, Markdown, and text-based PDF.',
    );
  }
}
