// Answer history is paginated and read-only; expanding an entry never submits or regenerates it.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../l10n/localization.dart';
import '../practice/source_viewer.dart';
import '../shared/widgets.dart';
import 'library_view_model.dart';

class AnswerHistoryPage extends StatefulWidget {
  const AnswerHistoryPage({super.key});
  @override
  State<AnswerHistoryPage> createState() => _AnswerHistoryPageState();
}

class _AnswerHistoryPageState extends State<AnswerHistoryPage> {
  final _records = <AnswerRecord>[];
  bool _loading = false, _more = true, _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await context.read<LibraryViewModel>().questions.history(
        offset: _records.length,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page);
        _more = page.length == 40;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final library = context.watch<LibraryViewModel>();
    final colors = Theme.of(context).colorScheme;
    return PageFrame(
      eyebrow: l.library,
      title: l.answerHistory,
      subtitle: l.answerHistoryHelp,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/library'),
            icon: const Icon(Icons.arrow_back),
            label: Text(l.backToLibrary),
          ),
        ),
        const SizedBox(height: 20),
        if (_records.isEmpty && !_loading && !_failed)
          EmptyCard(
            icon: Icons.check_circle_outline,
            title: l.answerHistoryEmpty,
            body: l.answerHistoryEmptyHelp,
          ),
        for (final record in _records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ExpansionTile(
                key: ValueKey(record.attempt.id),
                leading: Icon(
                  record.attempt.correct
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: record.attempt.correct ? colors.primary : colors.error,
                ),
                title: Text(
                  record.question.prompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${record.attempt.correct ? l.historyCorrect : l.historyIncorrect} · '
                  '${MaterialLocalizations.of(context).formatMediumDate(record.attempt.at.toLocal())} '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(record.attempt.at.toLocal()))}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    record.question.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final option in record.question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              option.id.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Text(option.text)),
                          if (option.id == record.attempt.optionId)
                            Tooltip(
                              message: l.historyYourAnswer,
                              child: Icon(
                                Icons.radio_button_checked,
                                size: 20,
                                color: record.attempt.correct
                                    ? colors.primary
                                    : colors.error,
                              ),
                            ),
                          if (option.id == record.question.correctOptionId)
                            Tooltip(
                              message: l.historyRightAnswer,
                              child: Icon(
                                Icons.check,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Text(
                    l.historyExplanation,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(record.question.explanation),
                  const Divider(height: 28),
                  SourceCitation(
                    source: record.question.source,
                    materials: library.materials,
                    libraryDirectory: library.files?.directory,
                  ),
                ],
              ),
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        if (_failed) Notice(l.historyLoadError, error: true),
        if (!_loading && (_more || _failed))
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _load,
              child: Text(_failed ? l.retryHistory : l.loadMoreHistory),
            ),
          ),
      ],
    );
  }
}
