// Abstracts model discovery so provider transports remain outside settings presentation.

/// Lists usable model identifiers independently of API-key or gateway UI.
abstract interface class ModelCatalog {
  /// Discovers IDs for this endpoint only; secrets must not be forwarded to redirects.
  Future<List<String>> list(String baseUrl, String key);

  /// Cancels discovery when the settings session is disposed or replaced.
  void cancel();
}
