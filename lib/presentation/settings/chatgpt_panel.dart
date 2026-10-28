// Presents account/model actions without exposing registration identifiers as display labels.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/localization.dart';
import 'settings_view_model.dart';
import 'question_language_view_model.dart';

/// Renders saved accounts and models while keeping registration IDs out of user labels.
class ChatGptPanel extends StatelessWidget {
  const ChatGptPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final l = context.l10n;
    if (vm.chatGpt == null) return const SizedBox.shrink();
    final language = context.watch<QuestionLanguageViewModel>().resolved;
    final savedModel = vm.profile?.credentialRef == vm.chatGptAccount
        ? vm.profile?.model
        : null;
    final model = vm.chatGptModels.contains(savedModel)
        ? savedModel
        : vm.chatGptModels.firstOrNull;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chatGptTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.chatGptDetails),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [Text(l.chatGptHelp)],
            ),
            if (vm.profile?.chatGpt == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${l.chatGptActive}: ${l.diagnostic(vm.chatGptAccounts[vm.profile!.credentialRef] ?? 'ChatGPT account')} / ${vm.profile!.model}',
                ),
              ),
            const SizedBox(height: 24),
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
                          l.diagnostic(entry.value),
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
                OutlinedButton(
                  onPressed: vm.busy || !vm.loaded
                      ? null
                      : () => vm.signInChatGpt(),
                  child: Text(
                    vm.chatGptAccount == null
                        ? l.continueChatGpt
                        : l.chatGptSignInAgain,
                  ),
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
            if (vm.busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (model != null) ...[
              const Divider(height: 32),
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
                onChanged: vm.busy
                    ? null
                    : (id) {
                        if (id != null) {
                          vm.useChatGpt(id, language, test: false);
                        }
                      },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.busy
                    ? null
                    : () => vm.useChatGpt(model, language),
                child: Text(l.testConnection),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l.chatGptTestHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
