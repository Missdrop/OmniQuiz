// Implements opaque secret storage and identifier generation behind application ports.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../application/ports/repositories.dart';
import '../../domain/policies.dart';

/// OS secure-storage adapter; callers never persist the returned secret in SQLite.
class PlatformCredentialStore implements CredentialStore {
  PlatformCredentialStore(this.storage);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String reference) => storage.read(key: reference);
  @override
  Future<void> write(String reference, String secret) =>
      storage.write(key: reference, value: secret);
  @override
  Future<void> delete(String reference) => storage.delete(key: reference);
}

/// Production UUID implementation for application-generated identities.
class UuidGenerator implements IdGenerator {
  const UuidGenerator();
  @override
  String next() => const Uuid().v4();
}
