/// Abstract key-value store for cryptographic secrets.
///
/// Concrete implementations:
///   - Production: [FlutterSecureKeyValueStore] (Android Keystore / iOS Secure Enclave)
///   - Tests:      [InMemoryKeyStore]
abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}
