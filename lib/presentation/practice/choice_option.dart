// Keeps the established answer geometry; only answered/selected options receive a status fill.
import 'package:flutter/material.dart';

/// One full-width hit target; multi-line answers align with the marker's first baseline.
class ChoiceOption extends StatelessWidget {
  const ChoiceOption({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.incorrect,
    required this.onPressed,
  });
  final String label, text;
  final bool selected, correct, incorrect;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = incorrect ? scheme.error : scheme.primary;
    final highlighted = correct || incorrect || selected;
    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(18),
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurface,
          backgroundColor: correct
              ? scheme.secondaryContainer
              : incorrect
              ? scheme.errorContainer
              : selected
              ? scheme.primaryContainer
              : Colors.transparent,
          overlayColor: scheme.onSurface.withValues(alpha: .04),
          side: BorderSide(
            color: highlighted
                ? accent.withValues(alpha: .65)
                : scheme.outlineVariant,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlighted
                    ? accent.withValues(alpha: .12)
                    : scheme.onSurface.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (correct) ...[
              const SizedBox(width: 12),
              Icon(Icons.check_circle_outline, color: accent, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
