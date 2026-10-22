import '../../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_view_model.dart';
import 'language_view_model.dart';
import 'model_picker.dart';
import '../shared/widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controls});
  final Widget? controls;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _url = TextEditingController(text: 'https://api.openai.com/v1');
  final _model = TextEditingController();
  final _key = TextEditingController();
  bool _json = false, _noKey = false, _visible = false;
  String _language = '简体中文';
  @override
  void initState() {
    super.initState();
    final vm = context.read<SettingsViewModel>();
    void applyProfile() {
      if (!mounted) return;
      final profile = vm.profile;
      if (profile == null) return;
      setState(() {
        _url.text = profile.baseUrl;
        _model.text = profile.model;
        _json = profile.jsonMode;
        _language = profile.language;
      });
    }

    if (vm.loaded) {
      applyProfile();
    } else {
      vm.load().then((_) => applyProfile());
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final language = context.watch<LanguageViewModel>();
    return PageFrame(
      eyebrow: context.l10n.settingsEyebrow,
      title: context.l10n.settingsTitle,
      subtitle: context.l10n.settingsSubtitle,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!vm.loaded) const LinearProgressIndicator(),
        if (vm.message != null) Notice(vm.message!),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.aiProvider,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(context.l10n.gatewayTitle),
                  children: [
                    Text(context.l10n.gatewayHelp),
                    const SizedBox(height: 12),
                    SelectableText(context.l10n.gatewayAddressHelp),
                    const SizedBox(height: 12),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _url,
                  enabled: !vm.busy,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.l10n.apiBaseUrl,
                    helperText: context.l10n.apiBaseUrlHelp,
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _model,
                  enabled: !vm.busy,
                  decoration: InputDecoration(
                    labelText: context.l10n.modelId,
                    hintText: context.l10n.modelHint,
                  ),
                ),
                if (vm.catalog != null)
                  TextButton.icon(
                    key: const ValueKey('load-models'),
                    onPressed: vm.busy || !vm.loaded
                        ? null
                        : () async {
                            final models = await vm.loadModels(
                              _url.text,
                              _key.text,
                              _noKey,
                            );
                            if (!context.mounted || models.isEmpty) return;
                            final selected = await showDialog<String>(
                              context: context,
                              builder: (_) => ModelPicker(models: models),
                            );
                            if (mounted && selected != null) {
                              setState(() => _model.text = selected);
                            }
                          },
                    icon: const Icon(Icons.list_alt),
                    label: Text(context.l10n.loadModels),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _key,
                  enabled: !vm.busy && !_noKey,
                  obscureText: !_visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.apiKey,
                    hintText: vm.profile == null
                        ? context.l10n.pasteKey
                        : context.l10n.keepKey,
                    suffixIcon: IconButton(
                      tooltip: _visible
                          ? context.l10n.hideKey
                          : context.l10n.showKey,
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.noKey),
                  value: _noKey,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _noKey = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.jsonMode),
                  subtitle: Text(context.l10n.jsonModeHelp),
                  value: _json,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _json = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  key: ValueKey(_language),
                  decoration: InputDecoration(
                    labelText: context.l10n.questionLanguage,
                    helperText: context.l10n.questionLanguageHelp,
                    helperMaxLines: 3,
                  ),
                  items: ['简体中文', 'English']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _language = value!),
                ),
                const SizedBox(height: 24),
                Wrap(
                  key: const ValueKey('provider-actions'),
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: vm.busy || !vm.loaded
                          ? null
                          : () async {
                              final saved = await vm.save(
                                _url.text,
                                _model.text,
                                _key.text,
                                _json,
                                _language,
                                _noKey,
                              );
                              if (saved && mounted) _key.clear();
                            },
                      child: Text(context.l10n.saveSettings),
                    ),
                    OutlinedButton(
                      onPressed: vm.busy || !vm.loaded
                          ? null
                          : () => vm.test(
                              _url.text,
                              _model.text,
                              _key.text,
                              _json,
                              _noKey,
                            ),
                      child: Text(context.l10n.testConnection),
                    ),
                  ],
                ),
                if (vm.busy)
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ?widget.controls,
        Notice(context.l10n.privacyNotice),
        Text(
          'OmniQuiz 0.1.0 · GPL-3.0-only',
          style: TextStyle(color: Colors.black54),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'OmniQuiz',
            applicationVersion: '0.1.0',
            applicationLegalese: 'Copyright © 2026 OmniQuiz contributors\nLicensed under GPL-3.0-only',
          ),
          child: Text(context.l10n.licenses),
        ),
      ],
    );
  }
}
