// Serializes provider/account actions and activates validated settings through repository ports.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../application/generation/coordinator.dart';
import '../../application/ports/repositories.dart';
import '../../application/ports/model_catalog.dart';
import '../../application/use_cases/configure_provider.dart';
import '../../domain/models.dart';
import '../../infrastructure/ai/chatgpt_sessions.dart';
import '../../domain/ai_connection.dart';
import '../../application/ports/connection_repository.dart';
part 'settings_connections.dart';

/// Serializes account and API configuration actions so paid requests can be quiesced first.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this.profiles,
    this.credentials,
    this.configure,
    this.generator,
    this.coordinator, {
    this.catalog,
    this.chatGpt,
    this.questionLanguage,
    this.connectionRepository,
    this.applyConnectionChange,
    this.endPractice,
  });
  final ProfileRepository profiles;
  final CredentialStore credentials;
  final ConfigureProvider configure;
  final AiQuestionGenerator generator;
  final GenerationCoordinator coordinator;
  final ModelCatalog? catalog;
  final ChatGptSessions? chatGpt;
  final String Function()? questionLanguage;
  final ConnectionRepository? connectionRepository;
  final Future<void> Function(Future<void> Function())? applyConnectionChange;
  final Future<void> Function()? endPractice;
  AiConnections connections = AiConnections();
  final Map<String, List<String>> _accountModels = {};
  Map<String, String> chatGptAccounts = {};
  List<String> chatGptModels = [];
  String? chatGptAccount;
  bool signingIn = false;
  void cancelSignIn() => chatGpt?.cancelLogin();
  ProviderProfile? profile;
  bool busy = false, loaded = false;
  String? message;
  bool actionFailed = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    catalog?.cancel();
    cancelSignIn();
    super.dispose();
  }

  /// Loads non-secret configuration and safe account labels; no probe is sent.
  Future<void> load() async {
    actionFailed = false;
    try {
      if (connectionRepository != null) {
        connections = await connectionRepository!.load();
      }
      profile = await profiles.load();
      chatGptAccounts = await chatGpt?.accounts() ?? {};
      if (profile?.chatGpt == true) chatGptAccount = profile!.credentialRef;
    } catch (_) {
      message = 'Could not load provider settings.';
      actionFailed = true;
    }
    loaded = true;
    _notify();
  }

  Future<void> _chatGptAction(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    _notify();
    try {
      await coordinator.quiesce();
      await action();
    } catch (e) {
      message = e is AppFailure
          ? e.message
          : 'ChatGPT request failed. Sign in again or check your plan access.';
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Activates the first available model after a successful browser authorization.
  Future<void> signInChatGpt({bool newAccount = false}) =>
      connectionRepository != null
      ? connectSubscription(
          id: newAccount ? null : _selectedSubscription?.id,
          name: _selectedSubscription?.name ?? 'ChatGPT',
          account: newAccount ? null : chatGptAccount,
        ).then((_) {})
      : _chatGptAction(() async {
          late String id;
          chatGptModels = [];
          signingIn = true;
          _notify();
          try {
            id = await chatGpt!.signIn(
              clientId: newAccount ? null : chatGptAccount,
            );
          } finally {
            signingIn = false;
            chatGptAccounts = await chatGpt!.accounts();
            chatGptAccount = chatGpt!.lastRegistration ?? chatGptAccount;
          }
          chatGptAccount = id;
          await _loadAndUseChatGpt(id, firstModel: true);
        });

  /// Changes account explicitly, retaining its saved model only if still available.
  Future<void> selectChatGpt(String id) => connectionRepository != null
      ? _selectSavedSubscription(id)
      : _chatGptAction(() async {
          chatGptAccount = id;
          chatGptModels = [];
          await _loadAndUseChatGpt(id);
        });
  Future<void> _loadAndUseChatGpt(String id, {bool firstModel = false}) async {
    try {
      chatGptModels = (await chatGpt!.models(id))
          .where((model) => model.trim().isNotEmpty)
          .toSet()
          .toList();
      if (chatGptModels.isEmpty) throw const FormatException();
    } catch (_) {
      throw const AppFailure(
        'Account saved. Could not load available models. Load models again to finish setup.',
      );
    }
    final saved = profile;
    final model =
        !firstModel &&
            saved?.credentialRef == id &&
            chatGptModels.contains(saved?.model)
        ? saved!.model
        : chatGptModels.first;
    await _saveChatGpt(
      model,
      questionLanguage?.call() ?? saved?.language ?? '简体中文',
    );
  }

  Future<void> _saveChatGpt(
    String model,
    String language, {
    bool test = false,
  }) async {
    final id = chatGptAccount!;
    if (!chatGptModels.contains(model)) throw const FormatException();
    final candidate = ProviderProfile(
      baseUrl: 'https://api.openai.com/v1',
      model: model,
      credentialRef: id,
      chatGpt: true,
      language: language,
    );
    if (test) await generator.probe(candidate, '');
    await profiles.save(candidate);
    profile = candidate;
    message = 'ChatGPT is ready. New questions will use your selected account.';
  }

  /// Optionally probes before saving; ordinary model selection does not incur a test call.
  Future<void> useChatGpt(String model, String language, {bool test = true}) =>
      connectionRepository != null
      ? (test
            ? probeSubscription(chatGptAccount!, model)
            : saveSubscriptionConnection(
                id: _selectedSubscription?.id,
                name: _selectedSubscription?.name ?? 'ChatGPT',
                account: chatGptAccount!,
                model: model,
              ).then((_) {}))
      : _chatGptAction(() async {
          await _saveChatGpt(model, language, test: test);
        });

  /// Removes local access even if remote revocation cannot currently be confirmed.
  Future<void> signOutChatGpt() => connectionRepository != null
      ? disconnectSubscription(chatGptAccount!)
      : _chatGptAction(() async {
          final revoked = await chatGpt!.signOut(chatGptAccount!);
          chatGptModels = [];
          message = revoked ? 'Signed out of ChatGPT.' : 'Signed out locally. Disconnect OmniQuiz in ChatGPT Settings to confirm revocation.';
        });

  /// Reuses a saved secret only when the endpoint still matches its saved profile.
  Future<List<String>> loadModels(String url, String key, bool noKey) async {
    if (busy || _disposed || catalog == null) return [];
    busy = true;
    message = null;
    _notify();
    try {
      var secret = noKey ? '' : key.trim();
      if (!noKey && secret.isEmpty) {
        if (profile == null ||
            profile!.chatGpt ||
            url.trim() != profile!.baseUrl) {
          throw const AppFailure(
            'Enter the API key for this endpoint before testing.',
          );
        }
        secret = await credentials.read(profile!.credentialRef) ?? '';
      }
      return await catalog!.list(url.trim(), secret);
    } catch (e) {
      message = e is AppFailure ? e.message : 'Could not load models. Check the endpoint and key, or enter a model manually.';
      return [];
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Saves an API draft without treating an omitted key as permission to erase it.
  Future<bool> save(
    String url,
    String model,
    String key,
    bool jsonMode,
    String language,
    bool noKey,
  ) async {
    if (connectionRepository != null) {
      final active = connections.active;
      final saved = await saveApiConnection(
        id: active?.profile.chatGpt == false ? active!.id : null,
        name: active?.profile.chatGpt == false
            ? active!.name
            : Uri.tryParse(url)?.host ?? 'API',
        url: url,
        model: model,
        key: key,
        jsonMode: jsonMode,
        noKey: noKey,
        activate: true,
      );
      return saved != null;
    }
    if (busy) return false;
    busy = true;
    message = null;
    _notify();
    try {
      await coordinator.stop();
      await configure.save(
        baseUrl: url,
        model: model,
        key: noKey ? '' : key,
        jsonMode: jsonMode,
        language: language,
        replaceKey: noKey || key.isNotEmpty,
      );
      profile = await profiles.load();
      message = 'Settings saved. Your key is stored securely on this device.';
      return true;
    } catch (e) {
      message = e is AppFailure ? e.message : 'Could not save settings.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Probes a draft connection without activating it or changing stored credentials.
  Future<void> test(
    String url,
    String model,
    String key,
    bool jsonMode,
    bool noKey,
  ) async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      final candidate = ProviderProfile(
        baseUrl: url.trim(),
        model: model.trim(),
        jsonMode: jsonMode,
      );
      var secret = noKey ? '' : key.trim();
      if (!noKey && secret.isEmpty) {
        if (profile == null ||
            profile!.chatGpt ||
            candidate.baseUrl != profile!.baseUrl) {
          throw const AppFailure(
            'Enter the API key for this endpoint before testing.',
          );
        }
        secret = await credentials.read(profile!.credentialRef) ?? '';
      }
      await generator.probe(candidate, secret);
      message = 'Connection successful. The model returned valid JSON.';
    } catch (e) {
      message = e is AppFailure
          ? e.message
          : 'Connection test failed. Check secure storage and connectivity.';
    } finally {
      busy = false;
      _notify();
    }
  }
}
