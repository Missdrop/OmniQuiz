// Keeps saved connections and the generation profile mirror in one SQLite transaction.
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../application/ports/connection_repository.dart';
import '../../domain/ai_connection.dart';
import '../../domain/models.dart';
import 'codec.dart';
import 'database.dart';

/// The existing profile key is an atomic active-only projection for generation.
/// Account tokens and API keys are never serialized here or into library backups.
class SqlConnectionRepository implements ConnectionRepository {
  SqlConnectionRepository(this.database);
  final QuizDatabase database;
  static const key = 'ai_connections';
  @override
  Future<AiConnections> load() => database.transaction(() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='$key'")
        .getSingleOrNull();
    if (row != null) {
      final data =
          jsonDecode(row.read<String>('value')) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const AppFailure('Invalid saved AI connections.');
      }
      return AiConnections(
        activeId: data['activeId'] as String?,
        items: (data['items'] as List).map((raw) {
          final item = raw as Map<String, dynamic>;
          return AiConnection(
            id: item['id'] as String,
            name: item['name'] as String,
            profile: profileFromJson(item['profile'] as Map<String, dynamic>),
            noKey: item['noKey'] == true,
            needsLogin: item['needsLogin'] == true,
          );
        }).toList(),
      );
    }
    final previous = await database
        .customSelect("SELECT value FROM settings WHERE key='profile'")
        .getSingleOrNull();
    final profile = previous == null
        ? null
        : profileFromJson(
            jsonDecode(previous.read<String>('value')) as Map<String, dynamic>,
          );
    final id = const Uuid().v4();
    final state = AiConnections(
      activeId: profile == null ? null : id,
      items: [
        if (profile != null)
          AiConnection(
            id: id,
            name: profile.chatGpt ? 'ChatGPT' : Uri.parse(profile.baseUrl).host,
            profile: profile,
          ),
      ],
    );
    await _write(state);
    return state;
  });

  Future<void> _write(AiConnections state) async {
    await database.customStatement(
      "INSERT OR REPLACE INTO settings VALUES ('$key',?)",
      [
        jsonEncode({
          'version': 1,
          'activeId': state.activeId,
          'items': [
            for (final item in state.items)
              {
                'id': item.id,
                'name': item.name,
                'profile': profileToJson(item.profile),
                'noKey': item.noKey,
                'needsLogin': item.needsLogin,
              },
          ],
        }),
      ],
    );
    final active = state.active;
    if (active == null || active.needsLogin) {
      await database.customStatement(
        "DELETE FROM settings WHERE key='profile'",
      );
    } else {
      await database.customStatement(
        "INSERT OR REPLACE INTO settings VALUES ('profile',?)",
        [jsonEncode(profileToJson(active.profile))],
      );
    }
  }

  @override
  Future<AiConnections> save(
    AiConnection connection, {
    bool activate = false,
  }) => database.transaction(() async {
    final old = await load();
    final first = old.items.isEmpty;
    final items = [
      for (final item in old.items)
        item.id == connection.id ? connection : item,
      if (old.find(connection.id) == null) connection,
    ];
    final selected = activate || first ? connection.id : old.activeId;
    if (selected == connection.id && connection.needsLogin) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
    final next = AiConnections(items: items, activeId: selected);
    await _write(next);
    return next;
  });

  @override
  Future<AiConnections> activate(String id) => database.transaction(() async {
    final old = await load();
    final item = old.find(id);
    if (item == null) throw const AppFailure('Invalid saved AI connections.');
    if (item.needsLogin) {
      throw const AppFailure('Sign in to ChatGPT in Settings first.');
    }
    final next = AiConnections(items: old.items, activeId: id);
    await _write(next);
    return next;
  });

  @override
  Future<AiConnections> remove(String id) => database.transaction(() async {
    final old = await load();
    final next = AiConnections(
      items: old.items.where((item) => item.id != id).toList(),
      activeId: old.activeId == id ? null : old.activeId,
    );
    await _write(next);
    return next;
  });

  @override
  Future<AiConnections> markSignedOut(String credentialRef) =>
      database.transaction(() async {
        final old = await load();
        final affected =
            old.active?.profile.chatGpt == true &&
            old.active?.profile.credentialRef == credentialRef;
        final next = AiConnections(
          activeId: affected ? null : old.activeId,
          items: [
            for (final item in old.items)
              if (item.profile.chatGpt &&
                  item.profile.credentialRef == credentialRef)
                AiConnection(
                  id: item.id,
                  name: item.name,
                  profile: item.profile,
                  needsLogin: true,
                )
              else
                item,
          ],
        );
        await _write(next);
        return next;
      });
}
