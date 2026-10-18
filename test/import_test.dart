import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/application/use_cases/import_materials.dart';
import 'package:omniquiz/domain/policies.dart';
import 'package:omniquiz/infrastructure/documents/parsers.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';
import 'package:omniquiz/infrastructure/platform/credentials.dart';

void main() {
  test(
    'imports once, updates revisions, and reports invalid files independently',
    () async {
      final db = QuizDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SqlMaterialRepository(db);
      final importer = ImportMaterials(
        repo,
        TextDocumentParser(),
        const UuidGenerator(),
        SystemClock(),
      );
      ImportInput input(String text) => ImportInput(
        name: 'notes.md',
        origin: 'notes',
        bytes: utf8.encode(text),
      );
      expect((await importer.execute([input('First revision')])).imported, 1);
      expect((await importer.execute([input('First revision')])).unchanged, 1);
      final id = (await repo.documents()).single.id;
      expect((await importer.execute([input('Updated revision')])).imported, 1);
      expect((await repo.documents()).single.id, id);
      expect((await repo.chunks(null)).single.text, 'Updated revision');
      expect((await importer.execute([input('')])).errors, hasLength(1));
      expect((await repo.chunks(null)).single.text, 'Updated revision');
    },
  );
}
