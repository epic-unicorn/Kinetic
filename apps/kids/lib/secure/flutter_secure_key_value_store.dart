import 'package:kinetic_webdav/kinetic_webdav.dart';

/// Wraps [FlutterSecureStorage] as a [SecureKeyValueStore] for the kids app.
///
/// Uses Android Keystore-backed EncryptedSharedPreferences and iOS Keychain
/// with `first_unlock_this_device` accessibility.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  static const _android = AndroidOptions(encryptedSharedPreferences: true);
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  FlutterSecureKeyValueStore()
    : _storage = const FlutterSecureStorage(aOptions: _android, iOptions: _ios);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
