// Edits one connection draft; inactive edits and probes never switch the current AI.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/ai_connection.dart';
import '../../l10n/localization.dart';
import '../shared/widgets.dart';
import '../shared/support_links.dart';
import 'settings_view_model.dart';
import 'connection_manager.dart';
import 'model_picker.dart';

/// Owns one local draft; saved secrets are represented only by a blank keep-key field.
class ConnectionEditor extends StatefulWidget {
  const ConnectionEditor({super.key, required this.type, this.connection});
  final AiConnectionType type;
  final AiConnection? connection;
  @override
  State<ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<ConnectionEditor> {
  final _name = TextEditingController(),
      _url = TextEditingController(),
      _model = TextEditingController(),
      _key = TextEditingController();
  String? _id, _account;
  List<String> _models = [];
  bool _noKey = false, _json = false, _visible = false, _initialized = false;
  // A manager's previous save result does not describe this newly opened draft.
  bool _showMessage = false;
  bool get _subscription => widget.type == AiConnectionType.chatGptSubscription;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final item = widget.connection;
    _id = item?.id;
    _name.text = item?.name ?? connectionTypeLabel(context, widget.type);
    _url.text = item?.profile.baseUrl ?? 'https://api.openai.com/v1';
    _model.text = item?.profile.model ?? '';
    _noKey = item?.noKey ?? false;
    _json = item?.profile.jsonMode ?? false;
    if (_subscription) {
      _account = item?.profile.credentialRef;
      _models = [if (item != null) item.profile.model];
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _url, _model, _key]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _login({bool another = false}) async {
    setState(() => _showMessage = true);
    final vm = context.read<SettingsViewModel>();
    final item = await vm.connectSubscription(
      id: another ? null : _id,
      name: _name.text,
      account: another ? null : _account,
    );
    if (!mounted) return;
    setState(() {
      _account = item?.profile.credentialRef ?? vm.chatGptAccount;
      _models = vm.chatGptModels;
      if (item != null) {
        _id = item.id;
        _model.text = item.profile.model;
      } else if (_models.isEmpty) {
        _model.clear();
      }
    });
  }

  Future<void> _loadModels() async {
    setState(() => _showMessage = true);
    final vm = context.read<SettingsViewModel>();
    final models = _subscription
        ? (_account == null
              ? <String>[]
              : await vm.discoverSubscriptionModels(_account!))
        : await vm.discoverApiModels(
            id: _id,
            url: _url.text,
            key: _key.text,
            noKey: _noKey,
          );
    if (!mounted || models.isEmpty) return;
    if (_subscription) {
      setState(() {
        _models = models;
        if (!models.contains(_model.text)) _model.text = models.first;
      });
    } else {
      final selected = await showDialog<String>(
        context: context,
        builder: (_) => ModelPicker(models: models),
      );
      if (mounted && selected != null) setState(() => _model.text = selected);
    }
  }

  Future<void> _save(bool use) async {
    setState(() => _showMessage = true);
    final vm = context.read<SettingsViewModel>();
    AiConnection? item;
    if (_subscription) {
      if (_account == null || _model.text.isEmpty) return;
      item = await vm.saveSubscriptionConnection(
        id: _id,
        name: _name.text,
        account: _account!,
        model: _model.text,
        activate: use,
      );
    } else {
      item = await vm.saveApiConnection(
        id: _id,
        name: _name.text,
        url: _url.text,
        model: _model.text,
        key: _key.text,
        jsonMode: _json,
        noKey: _noKey,
        activate: use,
      );
    }
    if (item != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final l = context.l10n;
    final canSave =
        !vm.busy &&
        (!_subscription || (_account != null && _model.text.isNotEmpty));
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
          title: Text(
            widget.connection == null ? l.addConnection : l.editConnection,
          ),
        ),
        body: SafeArea(
          child: PageFrame(
            eyebrow: l.configureAi,
            title: connectionTypeLabel(context, widget.type),
            subtitle: _subscription
                ? l.subscriptionConnectionHelp
                : l.compatibleConnectionHelp,
            children: [
              if (vm.busy) const LinearProgressIndicator(),
              if (_showMessage && !vm.busy && vm.message != null)
                Notice(
                  vm.message!,
                  error: vm.actionFailed,
                  onDismiss: vm.dismissMessage,
                ),
              TextField(
                controller: _name,
                enabled: !vm.busy,
                maxLength: 80,
                decoration: InputDecoration(labelText: l.connectionName),
              ),
              const SizedBox(height: 20),
              if (_subscription) ...[
                Text(l.subscriptionSaveHelp),
                const SizedBox(height: 16),
                if (vm.chatGptAccounts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(_account),
                    initialValue: vm.chatGptAccounts.containsKey(_account)
                        ? _account
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.chatGptAccount),
                    items: [
                      for (final entry in vm.chatGptAccounts.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            l.diagnostic(entry.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.busy
                        ? null
                        : (value) async {
                            setState(() {
                              _account = value;
                              _models = [];
                              _model.clear();
                            });
                            await _loadModels();
                          },
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: vm.busy ? null : () => _login(),
                      child: Text(
                        _account == null
                            ? l.continueChatGpt
                            : l.chatGptSignInAgain,
                      ),
                    ),
                    if (_account != null)
                      TextButton(
                        onPressed: vm.busy ? null : () => _login(another: true),
                        child: Text(l.chatGptAddAccount),
                      ),
                    if (_account != null)
                      TextButton(
                        onPressed: vm.busy
                            ? null
                            : () async {
                                setState(() => _showMessage = true);
                                await vm.disconnectSubscription(_account!);
                                if (mounted) {
                                  setState(() {
                                    _models = [];
                                    _model.clear();
                                  });
                                }
                              },
                        child: Text(l.chatGptSignOut),
                      ),
                    if (vm.signingIn)
                      TextButton(
                        onPressed: vm.cancelSignIn,
                        child: Text(l.cancel),
                      ),
                    TextButton.icon(
                      onPressed: vm.busy
                          ? null
                          : () => openSupportLink(
                              context,
                              Uri.parse('https://chatgpt.com/settings/usage'),
                              l.chatGptUsage,
                            ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.chatGptUsage),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_models.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey('model-${_model.text}'),
                    initialValue: _models.contains(_model.text)
                        ? _model.text
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.chooseModel),
                    items: [
                      for (final model in _models)
                        DropdownMenuItem(
                          value: model,
                          child: Text(model, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: vm.busy
                        ? null
                        : (value) => setState(() => _model.text = value ?? ''),
                  ),
              ] else ...[
                TextField(
                  controller: _url,
                  enabled: !vm.busy,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l.apiBaseUrl,
                    helperText: l.compatibleAddressHelp,
                    helperMaxLines: 4,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _model,
                  enabled: !vm.busy,
                  decoration: InputDecoration(labelText: l.modelId),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _key,
                  enabled: !vm.busy && !_noKey,
                  obscureText: !_visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.apiKey,
                    hintText: _id == null ? l.pasteKey : l.keepKey,
                    suffixIcon: IconButton(
                      tooltip: _visible ? l.hideKey : l.showKey,
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.noKey),
                  value: _noKey,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _noKey = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.jsonMode),
                  subtitle: Text(l.jsonModeHelp),
                  value: _json,
                  onChanged: vm.busy
                      ? null
                      : (value) => setState(() => _json = value),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TextButton.icon(
                    key: const ValueKey('load-models'),
                    onPressed: vm.busy || (_subscription && _account == null)
                        ? null
                        : _loadModels,
                    icon: const Icon(Icons.list_alt),
                    label: Text(l.loadModels),
                  ),
                  OutlinedButton(
                    onPressed:
                        vm.busy ||
                            (_subscription &&
                                (_account == null || _model.text.isEmpty))
                        ? null
                        : () {
                            setState(() => _showMessage = true);
                            if (_subscription) {
                              vm.probeSubscription(_account!, _model.text);
                            } else {
                              vm.probeApiConnection(
                                id: _id,
                                url: _url.text,
                                model: _model.text,
                                key: _key.text,
                                noKey: _noKey,
                                jsonMode: _json,
                              );
                            }
                          },
                    child: Text(l.testConnection),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l.connectionSaveHelp),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: canSave ? () => _save(false) : null,
                    child: Text(
                      vm.connections.items.isEmpty
                          ? l.saveAndUseConnection
                          : l.saveConnection,
                    ),
                  ),
                  if (vm.connections.items.isNotEmpty &&
                      (_id == null || vm.connections.activeId != _id))
                    OutlinedButton(
                      onPressed: canSave ? () => _save(true) : null,
                      child: Text(l.saveAndUseConnection),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
