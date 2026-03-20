import 'package:kinetic_core/kinetic_core.dart';

/// In-memory [SecureKeyValueStore] for unit tests.
/// No encryption — local map only. Never use in production.
class InMemoryKeyStore implements SecureKeyValueStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  /// Exposes the raw store for assertion in tests.
  Map<String, String> get snapshot => Map.unmodifiable(_store);
}
