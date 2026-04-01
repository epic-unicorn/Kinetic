/// Abstract key-value store for cryptographic secrets.
///
/// Concrete implementations:
///   - Production: [FlutterSecureKeyValueStore] (Android Keystore / iOS Keychain)
///   - Tests:      [InMemoryKeyValueStore]
abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// In-memory [SecureKeyValueStore] for use in unit tests.
class InMemoryKeyValueStore implements SecureKeyValueStore {
  final _store = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<void> delete({required String key}) async => _store.remove(key);
}
