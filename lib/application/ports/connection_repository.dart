// Persistence contract for named connections and an explicit active selection.
import '../../domain/ai_connection.dart';

abstract interface class ConnectionRepository {
  /// Migrates the previous single profile once without reading any secrets.
  Future<AiConnections> load();

  /// First configuration becomes active; later additions require explicit activation.
  Future<AiConnections> save(AiConnection connection, {bool activate = false});

  /// Selects explicitly, without probing or choosing another item on failure.
  Future<AiConnections> activate(String id);

  /// Removing the active connection leaves no selection, never a paid fallback.
  Future<AiConnections> remove(String id);

  /// Signs out an account across its connections and clears its active selection.
  Future<AiConnections> markSignedOut(String credentialRef);
}
