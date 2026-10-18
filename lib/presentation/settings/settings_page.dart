import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_view_model.dart';
import '../shared/widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
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
    return PageFrame(
      eyebrow: 'Make it yours',
      title: 'Your AI. Your choice.',
      subtitle: 'Connect an OpenAI-compatible Chat Completions API. No OmniQuiz account or server.',
      children: [
        if (!vm.loaded) const LinearProgressIndicator(),
        if (vm.message != null) Notice(vm.message!),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI provider',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _url,
                  enabled: !vm.busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'API base URL',
                    helperText: 'Include /v1 if your provider requires it. Do not append /chat/completions.',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _model,
                  enabled: !vm.busy,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    hintText: 'Enter a model available from your provider',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _key,
                  enabled: !vm.busy && !_noKey,
                  obscureText: !_visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    hintText: vm.profile == null
                        ? 'Paste your API key'
                        : 'Leave blank to keep the saved key',
                    suffixIcon: IconButton(
                      tooltip: _visible ? 'Hide key' : 'Show key',
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This endpoint does not require a key'),
                  value: _noKey,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _noKey = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('JSON response mode'),
                  subtitle: const Text(
                    'Enable only if your provider supports response_format: json_object.',
                  ),
                  value: _json,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _json = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  key: ValueKey(_language),
                  decoration: const InputDecoration(
                    labelText: 'Question language',
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
                      child: const Text('Save settings'),
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
                      child: const Text('Test connection'),
                    ),
                  ],
                ),
                if (vm.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Notice(
          'Generation sends selected source excerpts to your chosen provider. Connection tests make a small paid API request. Keys are kept in system secure storage; documents and study progress stay local.',
        ),
        const Text(
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
          child: const Text('Open-source licenses'),
        ),
      ],
    );
  }
}
