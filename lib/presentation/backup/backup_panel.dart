import 'package:flutter/material.dart';

import '../../application/ports/backup.dart';
import '../../domain/models.dart';
import '../../l10n/localization.dart';
import '../shared/widgets.dart';

class BackupPanel extends StatefulWidget {
  const BackupPanel({
    super.key,
    required this.actions,
    required this.runExclusive,
  });
  final BackupActions actions;
  final Future<void> Function(Future<void> Function()) runExclusive;
  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  bool _busy = false;
  String? _message;

  Future<void> _run({required bool restore}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      int? count;
      await widget.runExclusive(() async {
        count = await (restore
            ? widget.actions.restore()
            : widget.actions.export());
      });
      if (mounted && count != null) {
        setState(
          () => _message = restore
              ? context.l10n.backupRestored(count!)
              : count! > 0
              ? context.l10n.backupMissingOriginals(count!)
              : context.l10n.backupSaved,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is AppFailure
              ? error.message
              : context.l10n.backupFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.restoreBackup),
        content: Text(context.l10n.restoreBackupHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.restoreBackup),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _run(restore: true);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.backupTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.backupHelp),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(restore: false),
                icon: const Icon(Icons.save_alt),
                label: Text(context.l10n.exportBackup),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _confirmRestore,
                icon: const Icon(Icons.restore),
                label: Text(context.l10n.restoreBackup),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Notice(_message!),
            ),
        ],
      ),
    ),
  );
}
