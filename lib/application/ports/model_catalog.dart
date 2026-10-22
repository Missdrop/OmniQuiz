abstract interface class ModelCatalog {
  Future<List<String>> list(String baseUrl, String key);
  void cancel();
}
