// Separates saved connections from the one explicit generation selection.
import 'models.dart';
export 'models.dart' show AiConnectionType;

/// Non-secret connection configuration; authentication stays in secure storage.
class AiConnection {
  const AiConnection({
    required this.id,
    required this.name,
    required this.profile,
    this.noKey = false,
    this.needsLogin = false,
  });
  final String id, name;
  final ProviderProfile profile;
  final bool noKey, needsLogin;
  AiConnectionType get type => profile.type;
}

/// A missing active ID disables generation, never choosing an implicit fallback.
class AiConnections {
  AiConnections({List<AiConnection> items = const [], this.activeId})
    : items = List.unmodifiable(items) {
    if (items.map((item) => item.id).toSet().length != items.length ||
        items.any(
          (item) =>
              item.id.isEmpty ||
              item.name.trim().isEmpty ||
              item.name.length > 80,
        ) ||
        (activeId != null && !items.any((item) => item.id == activeId))) {
      throw const AppFailure('Invalid saved AI connections.');
    }
  }
  final List<AiConnection> items;
  final String? activeId;
  AiConnection? get active => find(activeId);
  AiConnection? find(String? id) =>
      items.where((item) => item.id == id).firstOrNull;
}
