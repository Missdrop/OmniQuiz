import 'package:flutter/foundation.dart';

import '../../application/ports/repositories.dart';
import '../../domain/models.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel(this.questions);
  final QuestionRepository questions;
  List<ReviewEntry> _entries = [];
  List<ReviewEntry> get entries => List.unmodifiable(_entries);
  String? error;
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
