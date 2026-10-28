// Edits a temporary authoring draft; cancelling must not alter saved samples or cached questions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/generation_guidance.dart';
import '../../l10n/localization.dart';
import '../shared/widgets.dart';
import 'guidance_view_model.dart';

/// Keeps edits in a local draft. Only Save changes the persisted library policy.
class GuidanceDialog extends StatefulWidget {
  const GuidanceDialog({super.key});
  @override
  State<GuidanceDialog> createState() => _GuidanceDialogState();
}

class _GuidanceDialogState extends State<GuidanceDialog> {
  late final TextEditingController _requirements, _pasted;
  late List<ReferenceExample> _examples;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = context.read<GuidanceViewModel>().value;
    _requirements = TextEditingController(text: saved.requirements);
    _pasted = TextEditingController(text: saved.pastedExample);
    _examples = [...saved.examples];
  }

  @override
  void dispose() {
    _requirements.dispose();
    _pasted.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final files = await context.read<GuidanceViewModel>().importExamples(
      _examples,
      pastedExample: _pasted.text,
    );
    if (mounted) {
      setState(() {
        _examples = files;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    try {
      final draft = GenerationGuidance(
        requirements: _requirements.text.trim(),
        pastedExample: _pasted.text.trim(),
        examples: _examples,
      );
      final saved = await context.read<GuidanceViewModel>().save(draft);
      if (saved && mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = context.l10n.guidanceLimitError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GuidanceViewModel>();
    final l = context.l10n;
    return PopScope(
      canPop: !vm.busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l.guidanceTitle),
        content: SizedBox(
          width: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.guidanceHelp),
              const SizedBox(height: 20),
              TextField(
                controller: _requirements,
                enabled: !vm.busy,
                minLines: 3,
                maxLines: 7,
                maxLength: GenerationGuidance.requirementsLimit,
                decoration: InputDecoration(
                  labelText: l.extraRequirements,
                  hintText: l.extraRequirementsHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pasted,
                enabled: !vm.busy,
                minLines: 3,
                maxLines: 7,
                maxLength: GenerationGuidance.pastedLimit,
                decoration: InputDecoration(
                  labelText: l.pasteExamples,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: vm.busy ? null : _import,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l.importExamples),
              ),
              const SizedBox(height: 8),
              Text(
                l.guidanceFormats,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final example in _examples)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: ExpansionTile(
                    key: ValueKey(example.id),
                    title: Text(example.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(l.exampleCharacters(example.text.length)),
                    trailing: IconButton(
                      tooltip: l.removeExample,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: vm.busy
                          ? null
                          : () => setState(
                              () => _examples.removeWhere(
                                (e) => e.id == example.id,
                              ),
                            ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          example.text.length <= 2000
                              ? example.text
                              : '${example.text.substring(0, 2000)}\n…',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l.guidancePreservesQuestions,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (vm.busy) const LinearProgressIndicator(),
              if (_error != null || vm.error != null)
                Notice(_error ?? l.diagnostic(vm.error!), error: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.busy ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: vm.busy ? null : _save,
            child: Text(l.saveGuidance),
          ),
        ],
      ),
    );
  }
}
