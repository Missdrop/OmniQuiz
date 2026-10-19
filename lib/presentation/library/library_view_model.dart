import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../application/generation/coordinator.dart';
import '../../application/libraries/library_files.dart';
import '../../application/ports/repositories.dart';
import '../../application/use_cases/import_materials.dart';
import '../../domain/models.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(
    this.materials,
    this.questions,
    this.access,
    this.importer,
    this.coordinator, {
    this.files,
    this.archives,
  });
  final LibraryFiles? files;
  final ArchiveAccess? archives;
  bool get canImportZip => files != null && archives != null;
  final MaterialRepository materials;
  final QuestionRepository questions;
  final DocumentAccess access;
  final ImportMaterials importer;
  final GenerationCoordinator coordinator;
  List<StudyDocument> _documents = [];
  List<StudyDocument> get documents => List.unmodifiable(_documents);
  StudyStats stats = const StudyStats();
  bool busy = false;
  String? message;
  bool get supportsDirectories => access.supportsDirectories;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      _documents = await materials.documents();
      stats = await questions.stats();
    } catch (_) {
      message = 'Could not load your library.';
    }
    _notify();
  }

  Future<void> import({
    bool directory = false,
    bool sample = false,
    bool chineseSample = false,
  }) async {
    if (_disposed || busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      final inputs = sample
          ? [
              ImportInput(
                name: chineseSample ? '学习方法示例.md' : 'Learning science.md',
                origin: 'sample:learning-science',
                bytes: utf8.encode(chineseSample ? _chineseSample : _sample),
              ),
            ]
          : await (directory ? access.pickDirectory() : access.pickFiles());
      if (inputs.isEmpty) return;
      await coordinator.stop();
      final stored = <ImportInput>[];
      for (final input in inputs) {
        stored.add(files == null ? input : await files!.store(input));
      }
      final result = await importer.execute(stored);
      message =
          '${result.imported} imported · ${result.unchanged} unchanged'
          '${result.errors.isEmpty ? '' : '\n${result.errors.join('\n')}'}';
      await refresh();
    } catch (e) {
      message = e is AppFailure
          ? e.message
          : 'Import failed. Check file permissions and try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> importZip() async {
    final archiveAccess = archives;
    final destination = files;
    if (_disposed || busy || archiveAccess == null || destination == null) {
      return;
    }
    busy = true;
    message = null;
    _notify();
    var imported = 0, unchanged = 0;
    final errors = <String>[];
    try {
      await coordinator.stop();
      var received = false;
      await for (final input in archiveAccess.pickZip()) {
        if (_disposed) return;
        received = true;
        final stored = await destination.store(
          input,
          preserveDirectories: true,
        );
        final result = await importer.execute([stored]);
        imported += result.imported;
        unchanged += result.unchanged;
        errors.addAll(result.errors);
      }
      if (received) {
        message =
            '$imported imported · $unchanged unchanged'
            '${errors.isEmpty ? '' : '\n${errors.join('\n')}'}';
      }
    } catch (error) {
      message = error is AppFailure
          ? error.message
          : 'Could not import ZIP. Check storage space and file permissions.';
    } finally {
      await refresh();
      busy = false;
      _notify();
    }
  }

  Future<void> scan() async {
    final directory = files;
    if (_disposed || busy || directory == null) return;
    busy = true;
    message = null;
    _notify();
    var imported = 0, unchanged = 0;
    final errors = <String>[];
    try {
      await coordinator.stop();
      final seen = <String>{};
      var readFailed = false;
      await for (final entry in directory.scan()) {
        if (_disposed) return;
        final input = entry.input;
        if (input == null) {
          readFailed = true;
          errors.add(entry.error!);
          continue;
        }
        seen.add(input.origin);
        final result = await importer.execute([input]);
        imported += result.imported;
        unchanged += result.unchanged;
        errors.addAll(result.errors);
      }
      // Only reconcile after a complete traversal, never on lost permissions.
      if (!readFailed) {
        for (final document in await materials.documents()) {
          if (directory.containsOrigin(document.origin) &&
              !seen.contains(document.origin)) {
            await materials.removeDocument(document.id);
          }
        }
      }
      message =
          '$imported imported · $unchanged unchanged'
          '${errors.isEmpty ? '' : '\n${errors.join('\n')}'}';
    } catch (_) {
      message = 'Could not scan the library folder. Check that it is connected and grant folder access again.';
    } finally {
      await refresh();
      busy = false;
      _notify();
    }
  }

  Future<void> remove(String id) async {
    if (_disposed || busy) return;
    busy = true;
    _notify();
    try {
      await coordinator.stop();
      await materials.removeDocument(id);
      await refresh();
    } catch (_) {
      message = 'Could not remove this document.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<List<SourceChunk>> source(String id) => materials.chunks(id);
  static const _chineseSample = '''# 学习方法

检索练习是主动从记忆中回想信息，而不是只反复阅读。在查看答案前尝试回答问题，就是检索练习的一种形式。

间隔练习将学习安排在不同时间进行，集中练习则将学习放在一次连续的时段中。间隔能让学习者在遗忘发生后再次尝试回忆。

反馈有助于纠正错误。解释为什么答案正确，通常比只标记对错更有帮助。对于 AI 生成的解析，学习者应当核对原始资料。

交错练习在同一次学习中混合不同类型的题目，分块练习则将相似题目放在一起。混合不同题目能促使学习者判断适用的方法。

识别与回忆不同。从选项中认出熟悉的答案，不代表能在没有提示时解释概念。结合选择题与自我解释，可以发现这种差距。

评估学习效果时，应同时使用新题和熟悉的题目。反复练习完全相同的题目，可能只是在测量对选项答案的记忆，而不是对知识的理解。
''';
  static const _sample = '''# Learning science

Retrieval practice means actively recalling information from memory, instead of only rereading it. Answering a question before checking the answer is one way to practice retrieval.

Spaced practice distributes study sessions over time. Massed practice places them together in one session. Spacing creates opportunities to retrieve information after a delay.

Feedback helps learners correct errors. An explanation of why an answer is correct can be more useful than a correctness label alone. A learner should check generated explanations against the source material.

Interleaving mixes different kinds of problems within a study session. Blocked practice groups similar problems together. Mixing problems can require the learner to decide which method applies.

Recognition and recall differ. Recognizing a familiar answer among options does not necessarily mean that a learner can explain it without cues. Combining multiple-choice questions with self-explanation can reveal this gap.

Study progress should be evaluated using new questions as well as familiar ones. Repeating exactly the same item can measure memory for that item's answer rather than understanding of its topic.
''';
}
