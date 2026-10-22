import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/repositories.dart';

import 'persistence_test.dart' show chunk;

void main() {
  test(
    'v1 databases keep existing documents when adding the v2 chunk index',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'omniquiz-migration-',
      );
      final file = File('${directory.path}/quiz.sqlite');
      final old = QuizDatabase(NativeDatabase(file));
      await SqlMaterialRepository(old).importDocument(
        StudyDocument(
          id: 'd',
          name: 'Notes',
          revision: 'r',
          origin: 'notes',
          importedAt: DateTime.utc(2026),
          chunkCount: 1,
        ),
        [chunk],
      );
      // The v1 schema differs only by the absent chunk_document index.
      await old.customStatement('DROP INDEX chunk_document');
      await old.customStatement('PRAGMA user_version=1');
      await old.close();
      final upgraded = QuizDatabase(NativeDatabase(file));
      try {
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        expect(
          (await SqlMaterialRepository(upgraded).documents()).single.id,
          'd',
        );
        expect(
          await upgraded
              .customSelect(
                "SELECT name FROM sqlite_master WHERE name='chunk_document'",
              )
              .get(),
          hasLength(1),
        );
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
