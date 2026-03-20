import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinetic_core/kinetic_core.dart';

/// Production [SecureKeyValueStore] backed by Android Keystore / iOS Keychain.
///
/// Android: uses [EncryptedSharedPreferences] — hardware-backed on devices
/// with a secure element (including GrapheneOS).
///
/// iOS: uses the Keychain with [firstUnlockThisDeviceOnly] accessibility,
/// which prevents iCloud backup and is unavailable before first device unlock.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  FlutterSecureKeyValueStore()
    : _storage = const FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

  @override
  Future<String?> read({required String key}) =>
      _storage.read(key: key, aOptions: _androidOptions, iOptions: _iosOptions);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(
        key: key,
        value: value,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

  @override
  Future<void> delete({required String key}) => _storage.delete(
    key: key,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
