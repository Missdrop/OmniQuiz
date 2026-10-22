import 'package:flutter/foundation.dart';

import '../../application/generation/coordinator.dart';
import '../../application/ports/repositories.dart';
import '../../application/ports/model_catalog.dart';
import '../../application/use_cases/configure_provider.dart';
import '../../domain/models.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this.profiles,
    this.credentials,
    this.configure,
    this.generator,
    this.coordinator, {
    this.catalog,
  });
  final ProfileRepository profiles;
  final CredentialStore credentials;
  final ConfigureProvider configure;
  final AiQuestionGenerator generator;
  final GenerationCoordinator coordinator;
  final ModelCatalog? catalog;
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
    super.dispose();
  }

  Future<void> load() async {
    try {
      profile = await profiles.load();
    } catch (_) {
      message = 'Could not load provider settings.';
    }
    loaded = true;
    _notify();
  }

  Future<List<String>> loadModels(String url, String key, bool noKey) async {
    if (busy || _disposed || catalog == null) return [];
    busy = true;
    message = null;
    _notify();
    try {
      var secret = noKey ? '' : key.trim();
      if (!noKey && secret.isEmpty) {
        if (profile == null || url.trim() != profile!.baseUrl) {
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
        if (profile == null || candidate.baseUrl != profile!.baseUrl) {
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
