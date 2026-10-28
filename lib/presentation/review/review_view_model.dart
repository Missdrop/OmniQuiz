// Loads review entries and errors independently from the current practice question.

import 'package:flutter/foundation.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';

/// Loads the review queue and exposes recoverable repository failures.
class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel(this.questions);
  final QuestionRepository questions;
  List<ReviewEntry> _entries = [];
  List<ReviewEntry> get entries => List.unmodifiable(_entries);
  String? error;
  void dismissError() {
    error = null;
    _notify();
  }

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
      _entries = await questions.reviews();
      error = null;
    } catch (_) {
      error = 'Could not load your review queue.';
    }
    _notify();
  }
}
