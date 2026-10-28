// Reads samples separately from knowledge sources and delegates session-safe persistence.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/repositories.dart';
import '../../domain/generation_guidance.dart';
import '../../domain/models.dart';

/// Edits library-specific guidance without importing sample papers as knowledge.
class GuidanceViewModel extends ChangeNotifier {
  GuidanceViewModel(
    this.repository,
    this.access,
    this.parser,
    this.applyChanges,
  );
  final GenerationGuidanceRepository repository;
  final DocumentAccess access;
  final DocumentParser parser;
  final Future<void> Function(Future<void> Function()) applyChanges;
  GenerationGuidance value = GenerationGuidance();
  bool busy = false, _disposed = false;
  String? error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Load failures remain recoverable: saving a new draft can replace bad data.
  Future<void> load() async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      value = await repository.load();
    } catch (_) {
      error = 'Could not load question guidance. Save it again to repair it.';
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Returns a draft addition; cancelling the dialog does not change stored data.
  Future<List<ReferenceExample>> importExamples(
    List<ReferenceExample> existing, {
    String pastedExample = '',
  }) async {
    if (busy) return existing;
    busy = true;
    error = null;
    _notify();
    try {
      final inputs = await access.pickFiles();
      final next = [...existing];
      for (final input in inputs) {
        if (input.bytes.length > 20 * 1024 * 1024) {
          throw const AppFailure('File exceeds 20 MB.');
        }
        final sections = await parser.parse(input);
        final text = sections
            .map((s) => '[${s.location}]\n${s.text.trim()}')
            .join('\n\n')
            .trim();
        if (sections.every((s) => s.text.trim().isEmpty)) {
          throw const AppFailure('No readable text found.');
        }
        final id = sha256.convert(utf8.encode(text)).toString();
        if (next.any((e) => e.id == id)) continue;
        final name = input.name.split(RegExp(r'[/\\]')).last;
        next.add(
          ReferenceExample(
            id: id,
            name: name,
            text: text,
            originalBytes: List.unmodifiable(input.bytes),
          ),
        );
        // Validate before returning additions, so an oversized selection is atomic.
        GenerationGuidance(examples: next, pastedExample: pastedExample);
      }
      return next;
    } catch (failure) {
      error = failure is AppFailure
          ? failure.message
          : 'Could not import reference examples.';
      return existing;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Serialize writes and let the practice session own cancellation/resumption.
  Future<bool> save(GenerationGuidance draft) async {
    if (busy) return false;
    // A no-op save must not clear an answer choice or replace a paid buffer.
    // An earlier load/import error still allows the same draft to repair storage.
    if (error == null &&
        jsonEncode(value.toJson()) == jsonEncode(draft.toJson())) {
      return true;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await applyChanges(() async {
        await repository.save(draft);
        value = draft;
      });
      return true;
    } catch (_) {
      error = 'Could not save question guidance. Please try again.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
