// Regression coverage for configurable refill boundaries, persistence and inline source previews.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniquiz/app/dependencies.dart';
import 'package:omniquiz/application/ports/repositories.dart';
import 'package:omniquiz/domain/generation_guidance.dart';
import 'package:omniquiz/domain/models.dart';
import 'package:omniquiz/infrastructure/persistence/database.dart';
import 'package:omniquiz/infrastructure/persistence/generation_guidance_repository.dart';
import 'package:omniquiz/l10n/localization.dart';
import 'package:omniquiz/presentation/practice/guidance_dialog.dart';
import 'package:omniquiz/presentation/practice/guidance_view_model.dart';
import 'package:omniquiz/presentation/practice/source_viewer.dart';
import 'package:provider/provider.dart';

import 'ai_test.dart' show MemoryCredentials;
import 'generation_guidance_test.dart' show GuidanceGenerator, SamplePicker;

class _MemoryGuidance implements GenerationGuidanceRepository {
  GenerationGuidance value = GenerationGuidance();
  @override
  Future<GenerationGuidance> load() async => value;
  @override
  Future<void> save(GenerationGuidance draft) async {
    value = draft;
  }
}

class _NoParser extends Fake implements DocumentParser {}

class _Materials extends Fake implements MaterialRepository {
  @override
  Future<List<StudyDocument>> documents() async => [];
}

Widget _localized(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  test('old guidance defaults to 10/10; numeric settings survive persistence and validate ranges', () async {
    final legacy = GenerationGuidance.fromJson({
      'requirements': 'Use scenarios.',
    });
    expect(legacy.questionsPerBatch, 10);
    expect(legacy.refillThreshold, 10);
    for (final pair in [
      [0, 10],
      [51, 10],
      [10, -1],
      [10, 101],
    ]) {
      expect(
        () => GenerationGuidance(
          questionsPerBatch: pair[0],
          refillThreshold: pair[1],
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    final db = QuizDatabase(NativeDatabase.memory());
    try {
      await SqlGenerationGuidanceRepository(db)
          .save(GenerationGuidance(questionsPerBatch: 7, refillThreshold: 0));
      final restored = await SqlGenerationGuidanceRepository(db).load();
      expect(restored.questionsPerBatch, 7);
      expect(restored.refillThreshold, 0);
    } finally {
      await db.close();
    }
  });

  test('custom batches trigger exactly at the threshold; saving retains cache and current choice', () async {
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
        'model',
        'key',
        false,
        'English',
        false,
      );
      await deps.guidance.save(
        GenerationGuidance(questionsPerBatch: 7, refillThreshold: 3),
      );
      await deps.practice.startPractice();
      expect(ai.requests.map((r) => r.count), [7]);
      final ready = await deps.practice.questions.ready(null);
      for (final q in ready.take(3)) {
        await deps.practice.questions.flagQuestion(q.id);
      }
      await deps.coordinator.replenish();
      expect(
        ai.calls,
        1,
        reason: 'Four left is above the configured threshold',
      );
      await deps.practice.questions.flagQuestion(ready[3].id);
      await Future.wait([
        deps.coordinator.replenish(),
        deps.coordinator.replenish(),
      ]);
      expect(ai.requests.map((r) => r.count), [7, 7]);
      expect(await deps.practice.questions.readyCount(null), 10);
      await deps.practice.refresh();
      final current = deps.practice.current!.id;
      deps.practice.choose('b');
      await deps.guidance.save(
        GenerationGuidance(questionsPerBatch: 4, refillThreshold: 0),
      );
      await deps.coordinator.replenish();
      expect(deps.practice.current!.id, current);
      expect(deps.practice.selected, 'b');
      expect(await deps.practice.questions.readyCount(null), 10);
      expect(ai.calls, 2);
      for (final q in await deps.practice.questions.ready(null)) {
        await deps.practice.questions.flagQuestion(q.id);
      }
      await deps.coordinator.replenish();
      expect(ai.requests.last.count, 4);
      expect(await deps.practice.questions.readyCount(null), 4);
    } finally {
      await deps.dispose();
    }
  });

  testWidgets(
    'numeric editor validates, saves and cancels on a narrow enlarged layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _MemoryGuidance();
      final vm = GuidanceViewModel(
        repo,
        SamplePicker(),
        _NoParser(),
        (persist) => persist(),
      );
      await vm.load();
      await tester.pumpWidget(
        _localized(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: const GuidanceDialog(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('questions-per-batch')),
            )
            .controller!
            .text,
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('questions-per-batch')),
        '0',
      );
      await tester.enterText(
        find.byKey(const ValueKey('refill-threshold')),
        '101',
      );
      await tester.tap(find.text('Save question settings'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 50.'), findsOneWidget);
      expect(find.text('Enter a whole number from 0 to 100.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('questions-per-batch')),
        '13',
      );
      await tester.enterText(
        find.byKey(const ValueKey('refill-threshold')),
        '4',
      );
      await tester.tap(find.text('Save question settings'));
      await tester.pumpAndSettle();
      expect(repo.value.questionsPerBatch, 13);
      expect(repo.value.refillThreshold, 4);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('questions-per-batch')),
        '2',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.value.questionsPerBatch, 13);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );

  testWidgets(
    'source shows only filename and page until expanded underneath its button',
    (tester) async {
      final source = SourceChunk(
        id: 's',
        documentId: 'd',
        documentName: 'notes.pdf',
        revision: 'r',
        location: 'Page 3 · characters 1–2400',
        text: 'Saved source text for this question.',
      );
      await tester.pumpWidget(
        _localized(
          SingleChildScrollView(
            child: SourceCitation(
              key: const ValueKey('q1'),
              source: source,
              materials: _Materials(),
            ),
          ),
        ),
      );
      expect(find.text('Saved source text for this question.'), findsNothing);
      expect(find.textContaining('characters'), findsNothing);
      expect(find.textContaining('Page 3'), findsOneWidget);
      await tester.tap(find.text('View original source'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Saved source text for this question.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(SourceViewer)).dy,
        greaterThan(tester.getBottomLeft(find.text('Hide source')).dy),
      );
      await tester.tap(find.text('Hide source'));
      await tester.pumpAndSettle();
      expect(find.byType(SourceViewer), findsNothing);
    },
  );
}
