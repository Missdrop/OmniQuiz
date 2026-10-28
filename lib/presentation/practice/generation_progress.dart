// Shows real batch phases and elapsed time, never an invented percentage.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/generation/coordinator.dart';
import '../../l10n/localization.dart';

/// A ticking label keeps long model requests visibly alive while cached answers remain usable.
class GenerationProgress extends StatefulWidget {
  const GenerationProgress({
    super.key,
    required this.status,
    required this.available,
    this.compact = false,
  });
  final GenerationStatus status;
  final int available;
  final bool compact;
  @override
  State<GenerationProgress> createState() => _GenerationProgressState();
}

class _GenerationProgressState extends State<GenerationProgress> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now()
        .toUtc()
        .difference(widget.status.startedAt ?? DateTime.now().toUtc())
        .inSeconds
        .clamp(0, 86400);
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    context.l10n.diagnostic(widget.status.message),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    context.l10n.generationElapsed(seconds, widget.available),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (seconds >= 60)
                    Text(
                      context.l10n.slowGenerationHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 10),
        Text(context.l10n.diagnostic(widget.status.message)),
        Text(
          context.l10n.generationElapsed(seconds, widget.available),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (seconds >= 60)
          Text(
            context.l10n.slowGenerationHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
