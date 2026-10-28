// Quality ratings inform later batches without extra requests or becoming answer evidence.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'generation_guidance_test.dart' show GuidanceGenerator;

void main() {
  test('good, bad and error notes enter subsequent generation only in the current source scope', () async {
    final ai = GuidanceGenerator();
    final deps = await AppDependencies.create(
      database: QuizDatabase(NativeDatabase.memory()),
      credentialStore: MemoryCredentials(),
      ai: ai,
    );
    try {
      await deps.library.import(sample: true);
      await deps.settings.save(
        'https://example.test/v1',
        'm',
        'key',
        false,
        'English',
        false,
      );
      await deps.practice.startPractice();
      await deps.practice.refresh();
      final ready = await deps.practice.questions.ready(null);
      final calls = ai.calls;
      for (var i = 0; i < 3; i++) {
        await deps.practice.questions.rate(
          ready[i].id,
          QuestionRating.values[i],
          note: i == 2
              ? 'The alternatives overlap; use distinct distractors.'
              : 'Style feedback',
        );
      }
      expect(
        ai.calls,
        calls,
        reason: 'A vote does not send an additional inference request',
      );
      expect(
        await deps.practice.questions.generationFeedback('another-source'),
        isEmpty,
      );
      for (final question in await deps.practice.questions.ready(null)) {
        await deps.practice.questions.flagQuestion(question.id);
      }
      await deps.coordinator.replenish();
      final feedback = ai.requests.last.qualityFeedback;
      expect(
        feedback.map((item) => item.rating).toSet(),
        QuestionRating.values.toSet(),
      );
      expect(feedback.first.note, contains('distinct distractors'));
      final document = deps.library.documents.single;
      await deps.practice.endPractice();
      await deps.library.materials.importDocument(
        StudyDocument(
          id: document.id,
          name: document.name,
          revision: 'updated',
          origin: document.origin,
          importedAt: DateTime.now(),
          chunkCount: 1,
        ),
        [
          SourceChunk(
            id: 'updated-source',
            documentId: document.id,
            documentName: document.name,
            revision: 'updated',
            location: 'Text',
            text: 'Updated material.',
          ),
        ],
      );
      expect(
        await deps.practice.questions.generationFeedback(null),
        isEmpty,
        reason: 'Votes on obsolete sources must not steer a revised syllabus',
      );
    } finally {
      await deps.dispose();
    }
  });
}
