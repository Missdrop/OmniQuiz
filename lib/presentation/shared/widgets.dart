import 'package:flutter/material.dart';

import '../../l10n/localization.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String eyebrow, title, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style:
                  (MediaQuery.sizeOf(context).width < 600
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.headlineLarge)
                      ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF65736A), height: 1.6),
            ),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFE8E2) : const Color(0xFFE7EFE5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      context.l10n.diagnostic(text),
      style: const TextStyle(height: 1.5),
    ),
  );
}

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
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.6),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}
