import 'package:crypto/crypto.dart';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../ports/repositories.dart';

class ImportMaterials {
  ImportMaterials(this.materials, this.parser, this.ids, this.clock);
  final MaterialRepository materials;
  final DocumentParser parser;
  final IdGenerator ids;
  final Clock clock;
  Future<ImportResult> execute(List<ImportInput> inputs) async {
    var imported = 0, unchanged = 0;
    final errors = <String>[];
    for (final input in inputs) {
      try {
        if (input.bytes.length > 20 * 1024 * 1024) {
          throw const AppFailure('File exceeds 20 MB.');
        }
        final revision = sha256.convert(input.bytes).toString();
        final previous = await materials.byOrigin(input.origin);
        if (previous?.revision == revision) {
          unchanged++;
          continue;
        }
        final sections = await parser.parse(input);
        if (sections.fold<int>(0, (n, s) => n + s.text.length) > 1000000) {
          throw const AppFailure(
            'Extracted text exceeds 1 million characters. Split the file.',
          );
        }
        final id = previous?.id ?? ids.next();
        final chunks = <SourceChunk>[];
        for (final section in sections) {
          final text = section.text.trim();
          for (var start = 0; start < text.length; start += 2200) {
            final end = (start + 2400).clamp(0, text.length);
            chunks.add(
              SourceChunk(
                id: ids.next(),
                documentId: id,
                documentName: input.name,
                revision: revision,
                location: '${section.location} · characters ${start + 1}–$end',
                text: text.substring(start, end),
              ),
            );
            if (end == text.length) break;
          }
        }
        if (chunks.isEmpty) throw const AppFailure('No readable text found.');
        await materials.importDocument(
          StudyDocument(
            id: id,
            name: input.name,
            revision: revision,
            origin: input.origin,
            importedAt: clock.now(),
            chunkCount: chunks.length,
          ),
          chunks,
        );
        imported++;
      } catch (error) {
        errors.add(
          '${input.name}: ${error is AppFailure ? error.message : 'Could not read this file.'}',
        );
      }
    }
    return ImportResult(imported, unchanged, List.unmodifiable(errors));
  }
}
