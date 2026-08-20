import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../sync/webdav_config_repository.dart';

/// Pushes / pulls `family.key.enc` using the personal vault key.
class FamilyVaultSync {
  static Future<void> pushIfPossible(WebDavConfigRepository configRepo) async {
    final config = await configRepo.load();
    final familyKey = config?.familyKeyBytes ?? await configRepo.loadFamilyKey();
    final entropy = await configRepo.loadFamilyEntropy();
    final personal = await configRepo.loadPersonalKeyBytes();
    if (config == null ||
        familyKey == null ||
        entropy == null ||
        personal == null) {
      return;
    }
    final client = WebDavClient(
      baseUrl: config.serverUrl,
      username: config.username,
      password: config.password,
    );
    try {
      await KineticVaultRemote.pushFamilyRecovery(
        client: client,
        username: config.username,
        personalKey: personal,
        familyKey: familyKey,
        entropy: entropy,
      );
    } finally {
      client.dispose();
    }
  }

  /// Restores a family key from the personal WebDAV folder. Returns true if
  /// a file was found and stored.
  static Future<bool> pullIfPresent({
    required WebDavClient client,
    required String username,
    required Uint8List personalKey,
    required WebDavConfigRepository configRepo,
  }) async {
    final recovered = await KineticVaultRemote.pullFamilyRecovery(
      client: client,
      username: username,
      personalKey: personalKey,
    );
    if (recovered == null) return false;
    await configRepo.saveFamilyKey(
      recovered.familyKey,
      entropy: recovered.entropy,
    );
    return true;
  }
}
