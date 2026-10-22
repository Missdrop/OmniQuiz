import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/model_catalog.dart';
import '../../domain/models.dart';

/// The standard OpenAI-compatible catalog, including self-hosted CLIProxyAPI.
class CompatibleModelCatalog implements ModelCatalog {
  CompatibleModelCatalog({
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
  }) : _factory = clientFactory ?? http.Client.new;
  final http.Client Function() _factory;
  final Duration timeout;
  final _active = <http.Client>{};

  @override
  Future<List<String>> list(String baseUrl, String key) async {
    // Apply the same endpoint validation as generation before sending a key.
    final profile = ProviderProfile(baseUrl: baseUrl, model: 'catalog');
    final client = _factory();
    _active.add(client);
    try {
      return await _read(client, profile, key).timeout(timeout);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Could not load models. Check the endpoint and key, or enter a model manually.',
      );
    } finally {
      _active.remove(client);
      client.close();
    }
  }

  Future<List<String>> _read(
    http.Client client,
    ProviderProfile profile,
    String key,
  ) async {
    final uri = Uri.parse(
      '${profile.baseUrl.replaceAll(RegExp(r'/+$'), '')}/models',
    );
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({if (key.isNotEmpty) 'Authorization': 'Bearer $key'});
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw const AppFailure(
        'Could not load models. Check the endpoint and key, or enter a model manually.',
      );
    }
    final bytes = <int>[];
    await for (final part in response.stream) {
      if (bytes.length + part.length > 1024 * 1024) {
        throw const AppFailure('Provider response exceeded the size limit.');
      }
      bytes.addAll(part);
    }
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final models = <String>{};
    for (final item in data['data'] as List) {
      if (item is Map && item['id'] is String) {
        final id = (item['id'] as String).trim();
        if (id.isNotEmpty) models.add(id);
      }
    }
    if (models.isEmpty) {
      throw const AppFailure(
        'No models are available. Sign in to a provider on your gateway, or enter a model manually.',
      );
    }
    return models.toList();
  }

  @override
  void cancel() {
    for (final client in _active.toList()) {
      client.close();
    }
    _active.clear();
  }
}
