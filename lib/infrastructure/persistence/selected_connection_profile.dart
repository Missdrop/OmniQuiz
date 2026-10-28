// Generation resolves the explicit active connection, never a stale legacy projection.
import 'package:uuid/uuid.dart';

import '../../application/ports/repositories.dart';
import '../../application/ports/connection_repository.dart';
import '../../domain/ai_connection.dart';
import '../../domain/models.dart';

/// Adapts the generation port to the connection catalog's source of truth.
class SelectedConnectionProfile implements ProfileRepository {
  SelectedConnectionProfile(this.connections);
  final ConnectionRepository connections;
  @override
  Future<ProviderProfile?> load() async {
    final active = (await connections.load()).active;
    return active == null || active.needsLogin ? null : active.profile;
  }

  @override
  Future<void> save(ProviderProfile profile) async {
    final state = await connections.load();
    final previous = state.active?.type == profile.type ? state.active : null;
    await connections.save(
      AiConnection(
        id: previous?.id ?? const Uuid().v4(),
        name:
            previous?.name ??
            (profile.chatGpt ? 'ChatGPT' : Uri.parse(profile.baseUrl).host),
        profile: profile,
        noKey: previous?.noKey ?? false,
      ),
      activate: true,
    );
  }
}
