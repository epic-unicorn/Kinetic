import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:parent/sync/webdav_config_repository.dart';
import 'package:parent/vault/vault_repository.dart';

void main() {
  late InMemoryKeyValueStore store;
  late WebDavConfigRepository configRepo;
  late VaultRepository vault;

  setUp(() {
    store = InMemoryKeyValueStore();
    configRepo = WebDavConfigRepository(store);
    vault = VaultRepository(store, configRepo);
  });

  test('isReady is false until unlock', () async {
    expect(await vault.isReady(), isFalse);
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    await vault.unlockWithPhrase(phrase);
    expect(await vault.isReady(), isTrue);
    expect(await vault.loadKey(), isNotNull);
    expect(await vault.verifyPhrase(phrase), isTrue);
    expect(
      await vault.verifyPhrase(
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      ),
      isFalse,
    );
  });

  test('unlockWithPhrase stores entropy so the mnemonic can be shown again',
      () async {
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    await vault.unlockWithPhrase(phrase);
    final words = await vault.loadPersonalMnemonic();
    expect(words, isNotNull);
    expect(words!.join(' '), phrase);
  });

  test('needsMigration is true when a key exists without vault_ready', () async {
    expect(await vault.needsMigration(), isFalse);
    await configRepo.savePersonalKey(Uint8List.fromList(List.filled(32, 1)));
    expect(await vault.isReady(), isFalse);
    expect(await vault.needsMigration(), isTrue);
    await vault.markReady();
    expect(await vault.needsMigration(), isFalse);
  });
}
