// Presents saved connections independently from the explicit active generation choice.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/ai_connection.dart';
import '../../l10n/localization.dart';
import '../shared/widgets.dart';
import 'settings_view_model.dart';
import 'connection_editor.dart';

String connectionTypeLabel(BuildContext context, AiConnectionType type) =>
    switch (type) {
      AiConnectionType.chatGptSubscription => context.l10n.chatGptTitle,
      AiConnectionType.openAiCompatible => context.l10n.openAiCompatible,
    };

/// Opens a normal route so desktop and phone share navigation and keyboard behavior.
Future<void> openConnectionManager(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const ConnectionManager()));

/// Shows the active choice consistently in Settings and Practice.
class ConnectionSummary extends StatelessWidget {
  const ConnectionSummary({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final active = vm.connections.active;
    final label = active == null
        ? context.l10n.noActiveConnection
        : '${active.name} · ${active.profile.model}';
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${context.l10n.generationConnection}: $label',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            OutlinedButton.icon(
              onPressed: vm.busy || !vm.loaded
                  ? null
                  : () => openConnectionManager(context),
              icon: const Icon(Icons.swap_horiz),
              label: Text(context.l10n.switchConnection),
            ),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(
              icon: Icons.hub_outlined,
              title: context.l10n.generationConnection,
            ),
            const SizedBox(height: 12),
            Text(label),
            const SizedBox(height: 8),
            Text(context.l10n.connectionSelectionHelp),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: vm.busy || !vm.loaded
                  ? null
                  : () => openConnectionManager(context),
              icon: const Icon(Icons.settings_input_component_outlined),
              label: Text(context.l10n.configureAi),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manages selection and independent records without exposing authentication secrets.
class ConnectionManager extends StatelessWidget {
  const ConnectionManager({super.key});
  Future<void> _add(BuildContext context) async {
    final type = await showDialog<AiConnectionType>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.addConnection),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in AiConnectionType.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    type == AiConnectionType.chatGptSubscription
                        ? Icons.account_circle_outlined
                        : Icons.api,
                  ),
                  title: Text(connectionTypeLabel(context, type)),
                  subtitle: Text(
                    type == AiConnectionType.chatGptSubscription
                        ? context.l10n.subscriptionConnectionHelp
                        : context.l10n.compatibleConnectionHelp,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(dialog, type),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
    if (context.mounted && type != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ConnectionEditor(type: type)),
      );
    }
  }

  Future<void> _delete(BuildContext context, AiConnection item) async {
    final vm = context.read<SettingsViewModel>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.deleteConnection),
        content: Text(context.l10n.deleteConnectionHelp(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.l10n.deleteConnection),
          ),
        ],
      ),
    );
    if (accepted == true) await vm.deleteConnection(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return PopScope(
      canPop: !vm.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) vm.dismissMessage();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: vm.busy ? null : () => Navigator.pop(context),
          ),
          title: Text(context.l10n.configureAi),
        ),
        body: SafeArea(
          child: PageFrame(
            eyebrow: context.l10n.generationConnection,
            title: context.l10n.savedConnections,
            subtitle: context.l10n.connectionSelectionHelp,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: vm.busy ? null : () => _add(context),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.addConnection),
                ),
              ),
              const SizedBox(height: 16),
              if (vm.busy) const LinearProgressIndicator(),
              if (vm.message != null)
                Notice(
                  vm.message!,
                  error: vm.actionFailed,
                  onDismiss: vm.dismissMessage,
                ),
              if (vm.connections.active == null)
                Notice(context.l10n.noActiveConnection),
              for (final item in [
                if (vm.connections.active != null) vm.connections.active!,
                ...vm.connections.items.where(
                  (item) => item.id != vm.connections.activeId,
                ),
              ])
                Card(
                  key: ValueKey('connection-${item.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(connectionTypeLabel(context, item.type)),
                        Text(
                          item.profile.chatGpt
                              ? context.l10n.diagnostic(
                                  vm.chatGptAccounts[item
                                          .profile
                                          .credentialRef] ??
                                      'ChatGPT account',
                                )
                              : item.profile.baseUrl,
                        ),
                        Text(item.profile.model),
                        if (item.needsLogin)
                          Text(context.l10n.connectionNeedsLogin),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (vm.connections.activeId == item.id)
                              Chip(
                                avatar: const Icon(Icons.check_circle_outline),
                                label: Text(context.l10n.currentConnection),
                              )
                            else
                              OutlinedButton(
                                onPressed: vm.busy || item.needsLogin
                                    ? null
                                    : () => vm.activateConnection(item.id),
                                child: Text(context.l10n.useConnection),
                              ),
                            OutlinedButton.icon(
                              onPressed: vm.busy
                                  ? null
                                  : () => Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => ConnectionEditor(
                                          type: item.type,
                                          connection: item,
                                        ),
                                      ),
                                    ),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.l10n.editConnection),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                              onPressed: vm.busy
                                  ? null
                                  : () => _delete(context, item),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(context.l10n.deleteConnection),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
