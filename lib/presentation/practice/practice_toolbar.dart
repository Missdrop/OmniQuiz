// Compact practice controls reuse the existing fields and buttons without a second settings banner.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/localization.dart';
import '../library/library_view_model.dart';
import '../settings/connection_manager.dart';
import '../settings/settings_view_model.dart';
import 'practice_view_model.dart';
import 'guidance_view_model.dart';
import 'guidance_dialog.dart';

/// Keeps scope/count together and configuration/session actions together; wraps on small screens.
class PracticeToolbar extends StatefulWidget {
  const PracticeToolbar({super.key, required this.hasLibrary});
  final bool hasLibrary;
  @override
  State<PracticeToolbar> createState() => _PracticeToolbarState();
}

class _PracticeToolbarState extends State<PracticeToolbar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsViewModel>();
      if (!settings.loaded) settings.load();
    });
  }

  Future<void> _configureQuestions() async {
    final guidance = context.read<GuidanceViewModel>();
    await guidance.load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: guidance,
        child: const GuidanceDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PracticeViewModel>();
    final library = context.watch<LibraryViewModel>();
    final guidance = context.watch<GuidanceViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final l = context.l10n;
    if (vm.reviewing) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        children: [
          Text(
            l.reviewPracticeTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          OutlinedButton.icon(
            onPressed: vm.leaveReview,
            icon: const Icon(Icons.arrow_back),
            label: Text(l.backToFresh),
          ),
        ],
      );
    }
    final active = settings.connections.active;
    final connection = active == null
        ? l.configureAi
        : '${active.name} · ${active.profile.model}';
    final ai = Tooltip(
      message: '${l.generationConnection}: $connection · ${l.switchConnection}',
      child: OutlinedButton.icon(
        onPressed: vm.busy || settings.busy || !settings.loaded
            ? null
            : () => openConnectionManager(context),
        icon: const Icon(Icons.hub_outlined, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            active?.profile.model ?? l.configureAi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    final configure = OutlinedButton.icon(
      onPressed: !widget.hasLibrary || library.busy || guidance.busy || vm.busy
          ? null
          : _configureQuestions,
      icon: const Icon(Icons.tune, size: 18),
      label: Text(l.guidanceTitle),
    );
    final session = vm.active
        ? OutlinedButton.icon(
            onPressed: vm.endPractice,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text(l.endPractice),
          )
        : FilledButton.icon(
            onPressed: library.busy || guidance.busy || !widget.hasLibrary
                ? null
                : vm.startPractice,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.startPractice),
          );
    final retry = vm.active && !vm.coordinator.enabled && !vm.generation.running
        ? OutlinedButton.icon(
            onPressed: vm.startPractice,
            icon: const Icon(Icons.refresh),
            label: Text(l.retryPractice),
          )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scope = SizedBox(
          width: constraints.maxWidth < 480 ? constraints.maxWidth : 220,
          child: DropdownButtonFormField<String>(
            key: ValueKey(vm.scope),
            initialValue: library.enabledDocuments.any((d) => d.id == vm.scope)
                ? vm.scope
                : '',
            isExpanded: true,
            decoration: InputDecoration(labelText: l.practiceScope),
            items: [
              DropdownMenuItem(value: '', child: Text(l.allMaterials)),
              ...library.enabledDocuments.map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: vm.busy
                ? null
                : (value) => vm.changeScope(value == '' ? null : value),
          ),
        );
        final count = Text(
          l.readyCount(vm.readyCount),
          style: Theme.of(context).textTheme.bodySmall,
        );
        final actions = [ai, configure, ?retry, session];
        if (constraints.maxWidth >= 920 &&
            MediaQuery.textScalerOf(context).scale(14) <= 16 &&
            retry == null) {
          return Row(
            children: [
              scope,
              const SizedBox(width: 18),
              count,
              const Spacer(),
              ...actions.expand((action) => [const SizedBox(width: 8), action]),
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [scope, count, ...actions],
        );
      },
    );
  }
}
