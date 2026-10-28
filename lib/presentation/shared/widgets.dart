// Shared page, notice and empty-state primitives keep spacing and theme contrast consistent.

import 'package:flutter/material.dart';

import '../../l10n/localization.dart';

/// Responsive, scrollable content frame shared by library, practice and settings pages.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
    this.compact = false,
    this.showHeader = true,
  });
  final String eyebrow, title, subtitle;
  final List<Widget> children;
  final bool compact;
  final bool showHeader;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: TextStyle(
                      letterSpacing: .6,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style:
                    (compact
                            ? Theme.of(context).textTheme.titleLarge
                            : MediaQuery.sizeOf(context).width < 600
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.headlineLarge)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!compact) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: compact ? 20 : 28),
            ],
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// A consistent visual anchor for groups of settings and connection controls.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ],
  );
}

/// Keeps metric cards aligned to the content edges, including wrapped mobile rows.
class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 4 : 2;
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 12),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// A localized status/error surface using theme-matched foreground contrast.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false, this.onDismiss});
  final String text;
  final bool error;
  final VoidCallback? onDismiss;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            context.l10n.diagnostic(text),
            style: TextStyle(
              height: 1.5,
              color: error
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        if (onDismiss != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: context.l10n.close,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            color: error
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ],
      ],
    ),
  );
}

/// An actionable empty state that remains readable at narrow widths.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 32),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}
