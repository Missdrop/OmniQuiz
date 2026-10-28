// Connection actions keep inactive drafts independent from the current paid request.
part of 'settings_view_model.dart';

extension ConnectionManagement on SettingsViewModel {
  AiConnection? get _selectedSubscription => connections.items
      .where(
        (item) =>
            item.profile.chatGpt &&
            item.profile.credentialRef == chatGptAccount,
      )
      .firstOrNull;
  Future<void> _selectSavedSubscription(String id) async {
    chatGptAccount = id;
    final models = await discoverSubscriptionModels(id);
    if (models.isEmpty) return;
    final saved = _selectedSubscription;
    await saveSubscriptionConnection(
      id: saved?.id,
      name: saved?.name ?? 'ChatGPT',
      account: id,
      model: models.contains(saved?.profile.model)
          ? saved!.profile.model
          : models.first,
    );
  }

  Future<T?> _connectionAction<T>(Future<T> Function() action) async {
    if (busy || _disposed || connectionRepository == null) return null;
    busy = true;
    message = null;
    actionFailed = false;
    _cancelledSignIn = false;
    _notify();
    try {
      connections = await connectionRepository!.load();
      final result = await action();
      return result;
    } catch (error) {
      actionFailed = !_isCancelledLogin(error);
      message = _isCancelledLogin(error)
          ? 'ChatGPT sign-in cancelled.'
          : error is AppFailure
          ? error.message
          : 'Could not save AI connections. Please try again.';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _accept(AiConnections value) {
    connections = value;
    profile = value.active?.needsLogin == true ? null : value.active?.profile;
    loaded = true;
  }

  String _name(String name) {
    final result = name.trim();
    if (result.isEmpty || result.length > 80) {
      throw const AppFailure('Enter a connection name (1–80 characters).');
    }
    return result;
  }

  bool _sameProfile(ProviderProfile? a, ProviderProfile b) =>
      a != null &&
      a.type == b.type &&
      a.baseUrl == b.baseUrl &&
      a.model == b.model &&
      a.credentialRef == b.credentialRef &&
      a.jsonMode == b.jsonMode;

  /// Configuration and selection publish together after the old loop has quiesced.
  Future<void> _changeGeneration(Future<void> Function() write) async {
    if (applyConnectionChange != null) {
      await applyConnectionChange!(write);
    } else {
      await coordinator.quiesce();
      await write();
    }
  }

  Future<void> _persist(AiConnection item, bool activate) async {
    final becomesActive =
        activate ||
        connections.items.isEmpty ||
        connections.activeId == item.id;
    Future<void> write() async =>
        _accept(await connectionRepository!.save(item, activate: activate));
    if (becomesActive &&
        !_sameProfile(connections.active?.profile, item.profile)) {
      await _changeGeneration(write);
    } else {
      await write();
    }
    message = connections.activeId == item.id
        ? 'Connection saved and selected for new questions.'
        : 'Connection saved. The current AI connection is unchanged.';
  }

  /// A blank key can reuse only this connection's credential at the same recipient.
  Future<String> _apiSecret(
    String? id,
    String url,
    String key,
    bool noKey,
  ) async {
    if (noKey) return '';
    if (key.trim().isNotEmpty) return key.trim();
    final old = connections.find(id);
    if (old == null ||
        old.profile.chatGpt ||
        old.noKey ||
        old.profile.baseUrl != url.trim()) {
      throw const AppFailure(
        'Enter the API key for this endpoint before testing.',
      );
    }
    final value = await credentials.read(old.profile.credentialRef);
    if (value == null) {
      throw const AppFailure(
        'API credentials are missing. Save them in Settings.',
      );
    }
    return value;
  }

  /// New keys receive new opaque references; a failed write leaves the old key intact.
  Future<AiConnection?> saveApiConnection({
    String? id,
    required String name,
    required String url,
    required String model,
    required String key,
    bool jsonMode = false,
    bool noKey = false,
    bool activate = false,
  }) => _connectionAction(() async {
    final label = _name(name);
    final old = connections.find(id);
    if (id != null && (old == null || old.profile.chatGpt)) {
      throw const AppFailure('Invalid saved AI connections.');
    }
    final secret = await _apiSecret(id, url, key, noKey);
    final effectiveNoKey = noKey || secret.isEmpty;
    final reuse =
        old != null &&
        old.profile.baseUrl == url.trim() &&
        key.trim().isEmpty &&
        old.noKey == effectiveNoKey;
    final ref = reuse ? old.profile.credentialRef : const Uuid().v4();
    final candidate = ProviderProfile(
      baseUrl: url.trim(),
      model: model.trim(),
      credentialRef: ref,
      jsonMode: jsonMode,
      language: questionLanguage?.call() ?? '简体中文',
      type: AiConnectionType.openAiCompatible,
    );
    final item = AiConnection(
      id: id ?? const Uuid().v4(),
      name: label,
      profile: candidate,
      noKey: effectiveNoKey,
    );
    if (!reuse) {
      try {
        await credentials.write(ref, secret);
      } catch (_) {
        throw const AppFailure(
          'Secure storage is unavailable. API key was not saved.',
        );
      }
    }
    try {
      await _persist(item, activate);
    } catch (_) {
      if (!reuse) {
        try {
          await credentials.delete(ref);
        } catch (_) {}
      }
      rethrow;
    }
    if (old != null && old.profile.credentialRef != ref) {
      await _deleteUnusedApiKey(old.profile.credentialRef);
    }
    return item;
  });

  Future<void> _deleteUnusedApiKey(String ref) async {
    if (connections.items.any((item) => item.profile.credentialRef == ref)) {
      return;
    }
    try {
      await credentials.delete(ref);
    } catch (_) {
      /* Already committed; never roll back a usable connection. */
    }
  }

  Future<List<String>> discoverApiModels({
    String? id,
    required String url,
    required String key,
    required bool noKey,
  }) async =>
      await _connectionAction(() async {
        final secret = await _apiSecret(id, url, key, noKey);
        return await catalog?.list(url.trim(), secret) ?? <String>[];
      }) ??
      [];

  Future<bool> probeApiConnection({
    String? id,
    required String url,
    required String model,
    required String key,
    required bool noKey,
    required bool jsonMode,
  }) async =>
      await _connectionAction(() async {
        final secret = await _apiSecret(id, url, key, noKey);
        final candidate = ProviderProfile(
          baseUrl: url.trim(),
          model: model.trim(),
          jsonMode: jsonMode,
          type: AiConnectionType.openAiCompatible,
        );
        await generator.probe(candidate, secret);
        message = 'Connection successful. The model returned valid JSON.';
        return true;
      }) ??
      false;

  Future<List<String>> discoverSubscriptionModels(String account) async =>
      await _connectionAction(() => _subscriptionModels(account)) ?? [];
  Future<List<String>> _subscriptionModels(String account) async {
    final models = (await chatGpt!.models(account))
        .where((model) => model.trim().isNotEmpty)
        .toSet()
        .toList();
    if (models.isEmpty) {
      throw const AppFailure(
        'Account saved. Could not load available models. Load models again to finish setup.',
      );
    }
    _accountModels[account] = models;
    chatGptModels = models;
    return models;
  }

  /// Browser authorization persists the account/model. Only the first connection auto-selects.
  Future<AiConnection?> connectSubscription({
    String? id,
    required String name,
    String? account,
  }) => _connectionAction(() async {
    final label = _name(name);
    chatGptModels = [];
    signingIn = true;
    _notify();
    String issued;
    try {
      issued = await chatGpt!.signIn(clientId: account);
    } finally {
      signingIn = false;
      chatGptAccounts = await chatGpt!.accounts();
      chatGptAccount = chatGpt!.lastRegistration ?? chatGptAccount;
      _notify();
    }
    chatGptAccount = issued;
    final models = await _subscriptionModels(issued);
    final old = connections.find(id);
    final model =
        old?.profile.credentialRef == issued &&
            models.contains(old?.profile.model)
        ? old!.profile.model
        : models.first;
    final item = _subscriptionItem(id, label, issued, model);
    await _persist(item, false);
    return item;
  });

  AiConnection _subscriptionItem(
    String? id,
    String name,
    String account,
    String model,
  ) => AiConnection(
    id: id ?? const Uuid().v4(),
    name: _name(name),
    profile: ProviderProfile(
      baseUrl: 'https://api.openai.com/v1',
      model: model,
      credentialRef: account,
      language: questionLanguage?.call() ?? '简体中文',
      type: AiConnectionType.chatGptSubscription,
    ),
  );

  Future<AiConnection?> saveSubscriptionConnection({
    String? id,
    required String name,
    required String account,
    required String model,
    bool activate = false,
  }) => _connectionAction(() async {
    final old = connections.find(id);
    if (id != null && (old == null || !old.profile.chatGpt)) {
      throw const AppFailure('Invalid saved AI connections.');
    }
    final previouslyUsable =
        old != null &&
        !old.needsLogin &&
        old.profile.credentialRef == account &&
        old.profile.model == model;
    if (!previouslyUsable &&
        !(_accountModels[account]?.contains(model) ?? false)) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
    final item = _subscriptionItem(id, name, account, model);
    await _persist(item, activate);
    return item;
  });

  Future<void> probeSubscription(String account, String model) =>
      _connectionAction(() async {
        await generator.probe(
          _subscriptionItem(null, 'ChatGPT', account, model).profile,
          '',
        );
        message = 'Connection successful. The model returned valid JSON.';
      });

  Future<bool> activateConnection(String id) async =>
      await _connectionAction(() async {
        final item = connections.find(id);
        if (item == null) {
          throw const AppFailure('Invalid saved AI connections.');
        }
        if (item.needsLogin) {
          throw const AppFailure('Sign in to ChatGPT in Settings first.');
        }
        Future<void> select() async =>
            _accept(await connectionRepository!.activate(id));
        if (connections.activeId == id && _sameProfile(profile, item.profile)) {
          await select();
        } else {
          await _changeGeneration(select);
        }
        message = 'Connection saved and selected for new questions.';
        return true;
      }) ??
      false;

  Future<bool> deleteConnection(String id) async =>
      await _connectionAction(() async {
        final old = connections.find(id);
        if (connections.activeId == id) {
          if (endPractice != null) {
            await endPractice!();
          } else {
            await coordinator.quiesce();
          }
        }
        _accept(await connectionRepository!.remove(id));
        if (old != null && !old.profile.chatGpt) {
          await _deleteUnusedApiKey(old.profile.credentialRef);
        }
        message = 'Connection removed. Other saved connections were kept.';
        return true;
      }) ??
      false;

  Future<void> disconnectSubscription(String account) =>
      _connectionAction(() async {
        if (connections.active?.profile.chatGpt == true &&
            connections.active?.profile.credentialRef == account) {
          if (endPractice != null) {
            await endPractice!();
          } else {
            await coordinator.quiesce();
          }
        }
        final revoked = await chatGpt!.signOut(account);
        _accountModels.remove(account);
        _accept(await connectionRepository!.markSignedOut(account));
        chatGptAccounts = await chatGpt!.accounts();
        message = revoked ? 'Signed out of ChatGPT.' : 'Signed out locally. Disconnect OmniQuiz in ChatGPT Settings to confirm revocation.';
      });
}
