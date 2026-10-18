import '../ports/repositories.dart';
import '../../domain/models.dart';
import '../../domain/policies.dart';

class ConfigureProvider {
  ConfigureProvider(this.profiles, this.credentials, this.ids);
  final ProfileRepository profiles;
  final CredentialStore credentials;
  final IdGenerator ids;
  Future<void> save({
    required String baseUrl,
    required String model,
    required String key,
    required bool jsonMode,
    required String language,
    bool replaceKey = false,
  }) async {
    final old = await profiles.load();
    if (old == null && key.trim().isEmpty && !replaceKey) {
      throw const AppFailure(
        'Enter an API key or explicitly select an endpoint without a key.',
      );
    }
    // Do not silently reuse a secret after changing the recipient endpoint.
    final sameEndpoint = old?.baseUrl == baseUrl.trim();
    if (!replaceKey && key.isEmpty && old != null && !sameEndpoint) {
      throw const AppFailure(
        'Enter a key for the new endpoint, or explicitly select no key.',
      );
    }
    final ref = !replaceKey && key.isEmpty && old != null
        ? old.credentialRef
        : ids.next();
    final profile = ProviderProfile(
      baseUrl: baseUrl.trim(),
      model: model.trim(),
      jsonMode: jsonMode,
      language: language,
      credentialRef: ref,
    );
    if (ref != old?.credentialRef) {
      try {
        await credentials.write(ref, key.trim());
      } catch (_) {
        throw const AppFailure(
          'Secure storage is unavailable. API key was not saved.',
        );
      }
    }
    try {
      await profiles.save(profile);
    } catch (_) {
      if (ref != old?.credentialRef) await credentials.delete(ref);
      rethrow;
    }
    if (old != null && old.credentialRef != ref) {
      // A cleanup failure must not roll back an already saved profile.
      try {
        await credentials.delete(old.credentialRef);
      } catch (_) {
        /* Retry by deleting app credentials in system settings. */
      }
    }
  }
}
