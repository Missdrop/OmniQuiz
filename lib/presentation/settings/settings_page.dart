// Groups shared preferences, AI connections, privacy and the appropriate update distribution UI.

import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_view_model.dart';
import 'language_view_model.dart';
import 'appearance_view_model.dart';
import 'question_language_view_model.dart';
import 'connection_manager.dart';
import '../shared/widgets.dart';
import '../shared/support_links.dart';
import '../../app/distribution.dart';
import 'privacy_policy_page.dart';
import '../updates/update_controller.dart';
import '../updates/update_panel.dart';

/// Keeps shared preferences above one entry point for named AI connections.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controls, this.updates});
  final Widget? controls;
  final UpdateController? updates;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    final vm = context.read<SettingsViewModel>();
    if (!vm.loaded) vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final language = context.watch<LanguageViewModel>();
    final appearance = context.watch<AppearanceViewModel>();
    final questionLanguage = context.watch<QuestionLanguageViewModel>();
    return PageFrame(
      eyebrow: context.l10n.settingsEyebrow,
      title: context.l10n.settingsTitle,
      subtitle: context.l10n.settingsSubtitle,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ThemeMode>(
                  isExpanded: true,
                  key: ValueKey('theme-${appearance.mode.name}'),
                  initialValue: appearance.mode,
                  decoration: InputDecoration(
                    labelText: context.l10n.appearance,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(context.l10n.systemTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(context.l10n.lightTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(context.l10n.darkTheme),
                    ),
                  ],
                  onChanged: appearance.saving
                      ? null
                      : (value) {
                          if (value != null) appearance.select(value);
                        },
                ),
                if (appearance.saveFailed) Text(context.l10n.themeSaveError),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  key: ValueKey('interface-${language.language}'),
                  initialValue: language.language,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.appLanguage,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(context.l10n.systemLanguage),
                    ),
                    const DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: language.saving
                      ? null
                      : (value) {
                          if (value != null) language.select(value);
                        },
                ),
                const SizedBox(height: 12),
                Text(context.l10n.appLanguageHelp),
                if (language.saveFailed)
                  Notice(context.l10n.languageSaveError, error: true),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'question-language-${questionLanguage.language}',
                  ),
                  initialValue: questionLanguage.language,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.questionLanguage,
                    helperText: context.l10n.questionLanguageHelp,
                    helperMaxLines: 3,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(context.l10n.systemLanguage),
                    ),
                    const DropdownMenuItem(value: '简体中文', child: Text('简体中文')),
                    const DropdownMenuItem(
                      value: 'English',
                      child: Text('English'),
                    ),
                  ],
                  onChanged: questionLanguage.saving
                      ? null
                      : (value) {
                          if (value != null) questionLanguage.select(value);
                        },
                ),
                if (questionLanguage.saveFailed)
                  Notice(context.l10n.languageSaveError, error: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!vm.loaded) const LinearProgressIndicator(),
        if (vm.message != null) Notice(vm.message!, error: vm.actionFailed),
        const ConnectionSummary(),
        const SizedBox(height: 20),
        ?widget.controls,
        if (microsoftStoreBuild) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.updateTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.storeUpdatesHelp),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => openSupportLink(
                      context,
                      Uri.parse(
                        'ms-windows-store://pdp/?ProductId=$microsoftStoreId',
                      ),
                      context.l10n.openMicrosoftStore,
                    ),
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(context.l10n.openMicrosoftStore),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (!microsoftStoreBuild && widget.updates != null) ...[
          const SizedBox(height: 20),
          UpdatePanel(controller: widget.updates!),
          const SizedBox(height: 20),
        ],
        Notice(context.l10n.privacyNotice),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              ),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(context.l10n.privacyPolicy),
            ),
            TextButton.icon(
              onPressed: () => openSupportLink(
                context,
                aiReportUri,
                context.l10n.reportToDeveloper,
              ),
              icon: const Icon(Icons.flag_outlined),
              label: Text(context.l10n.reportToDeveloper),
            ),
          ],
        ),
        Text(
          '${context.l10n.appName} · GPL-3.0-only',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: context.l10n.appName,
            applicationVersion: widget.updates?.version,
            applicationLegalese:
                'Copyright © 2026 Missdrop\nLicensed under GPL-3.0-only',
          ),
          child: Text(context.l10n.licenses),
        ),
      ],
    );
  }
}
