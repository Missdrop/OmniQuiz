// Renders optional update prompts and defers installation when users dismiss or postpone them.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../infrastructure/updates/release_updater.dart';
import '../../l10n/localization.dart';
import 'update_controller.dart';
import '../shared/widgets.dart';

Future<void> openUpdateWebsite(
  BuildContext context,
  UpdateController controller,
) async {
  final uri = controller.release?.website ?? ReleaseUpdater.website;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.updateWebsite),
        content: SelectableText(uri.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }
}

String updateStatusText(BuildContext context, UpdateController vm) {
  final l = context.l10n;
  return switch (vm.status) {
    UpdateStatus.idle => l.updateHelp,
    UpdateStatus.checking => l.updateChecking,
    UpdateStatus.current => l.updateCurrent,
    UpdateStatus.noRelease => l.updateNoRelease,
    UpdateStatus.available => l.updateFound(vm.release!.version.toString()),
    UpdateStatus.downloading => l.updateDownloading(
      (vm.progress * 100).floor(),
    ),
    UpdateStatus.ready =>
      vm.installPermissionNeeded ? l.updateInstallPermission : l.updateReady,
    UpdateStatus.installing => l.updateInstalling,
    UpdateStatus.failed => l.updateFailed,
    UpdateStatus.cancelled => l.updateCancelled,
  };
}

/// Settings controls for the standalone update channel.
class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key, required this.controller});
  final UpdateController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = context.l10n;
      return Card(
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                icon: Icons.system_update_alt,
                title: l.updateTitle,
              ),
              const SizedBox(height: 8),
              Text(l.updateVersion(controller.version ?? '…')),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.updateAutoCheck),
                subtitle: Text(l.updateHelp),
                value: controller.autoCheck,
                onChanged: !controller.loaded || controller.saving
                    ? null
                    : controller.setAutoCheck,
              ),
              const SizedBox(height: 12),
              Text(updateStatusText(context, controller)),
              if (controller.saveFailed) Text(l.updatePreferenceFailed),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.busy || !controller.loaded
                        ? null
                        : () => controller.check(),
                    icon: const Icon(Icons.system_update_alt),
                    label: Text(l.updateCheck),
                  ),
                  if (controller.release != null)
                    FilledButton(
                      onPressed: () => showUpdateDialog(context, controller),
                      child: Text(l.updateDetails),
                    ),
                  TextButton.icon(
                    onPressed: () => openUpdateWebsite(context, controller),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l.updateWebsite),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showUpdateDialog(
  BuildContext context,
  UpdateController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => UpdateDialog(controller: controller),
);

/// Release details and explicit download/install choices for one update.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.controller});
  final UpdateController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = context.l10n;
      final release = controller.release;
      return AlertDialog(
        scrollable: true,
        title: Text(l.updateFound(release?.version.toString() ?? '')),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.updateOptional),
              const SizedBox(height: 16),
              SelectableText(
                release?.notes.isNotEmpty == true
                    ? release!.notes
                    : l.updateNoNotes,
              ),
              const SizedBox(height: 16),
              Text(
                controller.asset == null
                    ? l.updateUnsupported
                    : l.updateInstallHelp,
              ),
              const SizedBox(height: 12),
              if (controller.status != UpdateStatus.available)
                Text(updateStatusText(context, controller)),
              if (controller.status == UpdateStatus.downloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: controller.progress),
              ],
              if (controller.saveFailed) Text(l.updatePreferenceFailed),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.updateLater),
          ),
          TextButton(
            onPressed: controller.busy || controller.saving
                ? null
                : () async {
                    await controller.skip();
                    if (context.mounted && !controller.saveFailed) {
                      Navigator.pop(context);
                    }
                  },
            child: Text(l.updateSkip),
          ),
          TextButton(
            onPressed: () => openUpdateWebsite(context, controller),
            child: Text(l.updateWebsite),
          ),
          if (controller.status == UpdateStatus.downloading)
            TextButton(
              onPressed: controller.cancelDownload,
              child: Text(l.updateCancelDownload),
            )
          else if (controller.asset != null)
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      if (controller.downloaded == null) {
                        await controller.download();
                      }
                      // Closing the notice postpones installation, even when a
                      // download that the user already started finishes later.
                      if (!context.mounted) return;
                      if (controller.status == UpdateStatus.ready ||
                          controller.downloaded != null) {
                        await controller.install();
                      }
                    },
              child: Text(
                controller.downloaded == null ? l.updateNow : l.updateInstall,
              ),
            ),
        ],
      );
    },
  );
}

/// One host per application session; closing a notice never blocks using the app.
class UpdateNoticeHost extends StatefulWidget {
  const UpdateNoticeHost({
    super.key,
    required this.controller,
    required this.child,
  });
  final UpdateController? controller;
  final Widget child;
  @override
  State<UpdateNoticeHost> createState() => _UpdateNoticeHostState();
}

class _UpdateNoticeHostState extends State<UpdateNoticeHost> {
  int _seen = 0;
  bool _showing = false;
  @override
  void initState() {
    super.initState();
    _seen = widget.controller?.notification ?? 0;
    widget.controller?.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller?.initialize());
    });
  }

  void _changed() {
    final controller = widget.controller!;
    if (controller.notification <= _seen || _showing || !mounted) return;
    _seen = controller.notification;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showing || controller.release == null) return;
      // Do not interrupt another modal (for example an active import dialog).
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _showing = true;
      await showUpdateDialog(context, controller);
      _showing = false;
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
