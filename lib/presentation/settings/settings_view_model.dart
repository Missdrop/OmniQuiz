import 'package:flutter/foundation.dart';

import '../../application/generation/coordinator.dart';
import '../../application/ports/repositories.dart';
import '../../application/ports/model_catalog.dart';
import '../../application/use_cases/configure_provider.dart';
import '../../domain/models.dart';
import '../../infrastructure/ai/chatgpt_sessions.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this.profiles,
    this.credentials,
    this.configure,
    this.generator,
    this.coordinator, {
    this.catalog,
    this.chatGpt,
  });
  final ProfileRepository profiles;
  final CredentialStore credentials;
  final ConfigureProvider configure;
  final AiQuestionGenerator generator;
  final GenerationCoordinator coordinator;
  final ModelCatalog? catalog;
  final ChatGptSessions? chatGpt;
  Map<String, String> chatGptAccounts = {};
  List<String> chatGptModels = [];
  String? chatGptAccount;
  bool signingIn = false;
  void cancelSignIn() => chatGpt?.cancelLogin();
  ProviderProfile? profile;
  bool busy = false, loaded = false;
  String? message;
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

  Future<void> load() async {
    try {
      profile = await profiles.load();
      chatGptAccounts = await chatGpt?.accounts() ?? {};
      if (profile?.chatGpt == true) chatGptAccount = profile!.credentialRef;
    } catch (_) {
      message = 'Could not load provider settings.';
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

  Future<void> signInChatGpt({bool newAccount = false}) =>
      _chatGptAction(() async {
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
        chatGptModels = [];
        chatGptModels = await chatGpt!.models(id);
      });
  Future<void> selectChatGpt(String id) => _chatGptAction(() async {
    chatGptAccount = id;
    chatGptModels = [];
    chatGptModels = await chatGpt!.models(id);
  });
  Future<void> useChatGpt(String model, String language) =>
      _chatGptAction(() async {
        final id = chatGptAccount!;
        if (!chatGptModels.contains(model)) throw const FormatException();
        final candidate = ProviderProfile(
          baseUrl: 'https://api.openai.com/v1',
          model: model,
          credentialRef: id,
          chatGpt: true,
          language: language,
        );
        await generator.probe(candidate, '');
        await profiles.save(candidate);
        profile = candidate;
        message =
            'ChatGPT is ready. New questions will use your selected account.';
      });
  Future<void> signOutChatGpt() => _chatGptAction(() async {
    final revoked = await chatGpt!.signOut(chatGptAccount!);
    chatGptModels = [];
    message = revoked ? 'Signed out of ChatGPT.' : 'Signed out locally. Disconnect OmniQuiz in ChatGPT Settings to confirm revocation.';
  });

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

  Future<bool> save(
    String url,
    String model,
    String key,
    bool jsonMode,
    String language,
    bool noKey,
  ) async {
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
