import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/localization.dart';
import 'settings_view_model.dart';

class ChatGptPanel extends StatefulWidget {
  const ChatGptPanel({super.key});
  @override
  State<ChatGptPanel> createState() => _ChatGptPanelState();
}

class _ChatGptPanelState extends State<ChatGptPanel> {
  String? _model;
  String _language = '简体中文';
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final l = context.l10n;
    if (vm.chatGpt == null) return const SizedBox.shrink();
    final model = vm.chatGptModels.contains(_model)
        ? _model
        : vm.chatGptModels.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chatGptTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l.chatGptHelp),
            if (vm.profile?.chatGpt == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${l.chatGptActive}: ${vm.chatGptAccounts[vm.profile!.credentialRef] ?? vm.profile!.credentialRef} / ${vm.profile!.model}',
                ),
              ),
            if (vm.chatGptAccounts.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(vm.chatGptAccount),
                isExpanded: true,
                initialValue: vm.chatGptAccounts.containsKey(vm.chatGptAccount)
                    ? vm.chatGptAccount
                    : null,
                decoration: InputDecoration(labelText: l.chatGptAccount),
                items: vm.chatGptAccounts.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: vm.busy
                    ? null
                    : (id) {
                        if (id != null) vm.selectChatGpt(id);
                      },
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: vm.busy || !vm.loaded
                      ? null
                      : () => vm.signInChatGpt(),
                  child: Text(l.continueChatGpt),
                ),
                if (vm.chatGptAccounts.isNotEmpty)
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => vm.signInChatGpt(newAccount: true),
                    child: Text(l.chatGptAddAccount),
                  ),
                if (vm.chatGptAccount != null)
                  TextButton(
                    onPressed: vm.busy ? null : vm.signOutChatGpt,
                    child: Text(l.chatGptSignOut),
                  ),
                if (vm.chatGptAccount != null)
                  TextButton(
                    onPressed: vm.busy
                        ? null
                        : () => vm.selectChatGpt(vm.chatGptAccount!),
                    child: Text(l.loadModels),
                  ),
                if (vm.signingIn)
                  TextButton(onPressed: vm.cancelSignIn, child: Text(l.cancel)),
              ],
            ),
            if (model != null) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('${vm.chatGptAccount}/$model'),
                initialValue: model,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.chooseModel),
                items: vm.chatGptModels
                    .toSet()
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(id, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: vm.busy ? null : (id) => setState(() => _model = id),
              ),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: InputDecoration(labelText: l.questionLanguage),
                items: ['简体中文', 'English']
                    .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: vm.busy
                    ? null
                    : (id) => setState(() => _language = id!),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: vm.busy
                    ? null
                    : () => vm.useChatGpt(model, _language),
                child: Text(l.chatGptUseModel),
              ),
            ],
            Text(l.chatGptTestHelp),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://chatgpt.com/settings/usage'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(l.chatGptUsage),
            ),
          ],
        ),
      ),
    );
  }
}
