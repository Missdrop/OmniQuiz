import '../../domain/models.dart';
import '../../domain/policies.dart';

class QuestionValidator {
  QuestionValidator(this.ids);
  final IdGenerator ids;
  String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  Set<String> _grams(String text) {
    final n = _normalize(text);
    return {for (var i = 0; i + 1 < n.length; i++) n.substring(i, i + 2)};
  }

  bool _similar(String a, String b) {
    if (_normalize(a) == _normalize(b)) return true;
    final x = _grams(a), y = _grams(b);
    final union = x.union(y).length;
    return union > 0 && x.intersection(y).length / union > .85;
  }

  List<Question> validate(List<dynamic> candidates, GenerationRequest request) {
    final accepted = <Question>[];
    for (final candidate in candidates.take(request.count * 2)) {
      try {
        final j = candidate as Map<String, dynamic>;
        final source = request.chunks.firstWhere((c) => c.id == j['sourceId']);
        final quote = j['quote'] as String;
        if (quote.trim().length < 4 ||
            !_normalize(source.text).contains(_normalize(quote))) {
          continue;
        }
        final question = Question(
          id: ids.next(),
          prompt: j['prompt'] as String,
          options: (j['options'] as List)
              .map((o) => AnswerOption(o['id'] as String, o['text'] as String))
              .toList(),
          correctOptionId: j['correctOptionId'] as String,
          explanation: j['explanation'] as String,
          topic: j['topic'] as String,
          source: source,
          quote: quote,
        );
        if ([
          ...request.recentPrompts,
          ...accepted.map((q) => q.prompt),
        ].any((p) => _similar(p, question.prompt))) {
          continue;
        }
        accepted.add(question);
        if (accepted.length == request.count) break;
      } catch (_) {
        /* Invalid candidates never reach the question bank. */
      }
    }
    if (accepted.isEmpty) {
      throw const AppFailure(
        'No valid, new questions were returned. Try another model or add more material.',
      );
    }
    return accepted;
  }
}
