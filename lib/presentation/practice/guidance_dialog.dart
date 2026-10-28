// Edits a temporary authoring draft; cancelling must not alter saved samples or cached questions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final TextEditingController _requirements,
      _pasted,
      _batchSize,
      _threshold;
  final _formKey = GlobalKey<FormState>();
  late List<ReferenceExample> _examples;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = context.read<GuidanceViewModel>().value;
    _requirements = TextEditingController(text: saved.requirements);
    _pasted = TextEditingController(text: saved.pastedExample);
    _batchSize = TextEditingController(text: '${saved.questionsPerBatch}');
    _threshold = TextEditingController(text: '${saved.refillThreshold}');
    _examples = [...saved.examples];
  }

  @override
  void dispose() {
    _requirements.dispose();
    _pasted.dispose();
    _batchSize.dispose();
    _threshold.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    try {
      final draft = GenerationGuidance(
        requirements: _requirements.text.trim(),
        pastedExample: _pasted.text.trim(),
        examples: _examples,
        questionsPerBatch: int.parse(_batchSize.text),
        refillThreshold: int.parse(_threshold.text),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.guidanceHelp),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('questions-per-batch'),
                  controller: _batchSize,
                  enabled: !vm.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l.questionsPerBatch,
                    helperText: l.questionsPerBatchHelp,
                    helperMaxLines: 3,
                    errorMaxLines: 2,
                  ),
                  validator: (text) {
                    final value = int.tryParse(text ?? '');
                    return value != null && value >= 1 && value <= 50
                        ? null
                        : l.questionsPerBatchError;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('refill-threshold'),
                  controller: _threshold,
                  enabled: !vm.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l.refillThreshold,
                    helperText: l.refillThresholdHelp,
                    helperMaxLines: 5,
                    errorMaxLines: 2,
                  ),
                  validator: (text) {
                    final value = int.tryParse(text ?? '');
                    return value != null && value >= 0 && value <= 100
                        ? null
                        : l.refillThresholdError;
                  },
                ),
                const SizedBox(height: 24),
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
                      title: Text(
                        example.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  Notice(
                    _error ?? l.diagnostic(vm.error!),
                    error: true,
                    onDismiss: () {
                      setState(() => _error = null);
                      vm.dismissError();
                    },
                  ),
              ],
            ),
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
