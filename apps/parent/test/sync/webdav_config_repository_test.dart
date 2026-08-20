import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:parent/sync/webdav_config_repository.dart';

void main() {
  group('WebDavConfigRepository API', () {
    test('WebDavConfigRepository can be imported', () {
      expect(WebDavConfigRepository, isNotNull);
    });

    test('SyncConfig model has required fields', () {
      final config = SyncConfig(
        serverUrl: 'https://dav.example.com',
        username: 'user@example.com',
        password: 'password123',
        parentId: '',
        personalKeyBytes: Uint8List.fromList(List.filled(32, 0)),
        familyKeyBytes: null,
      );

      expect(config.serverUrl, equals('https://dav.example.com'));
      expect(config.username, equals('user@example.com'));
      expect(config.password, equals('password123'));
      expect(config.personalKeyBytes.length, equals(32));
      expect(config.familyKeyBytes, isNull);
    });
  });

  group('requirePersonalKey', () {
    test('throws when no vault key is stored', () async {
      final repo = WebDavConfigRepository(InMemoryKeyValueStore());
      expect(repo.requirePersonalKey, throwsA(isA<StateError>()));
    });

    test('returns the stored key', () async {
      final store = InMemoryKeyValueStore();
      final repo = WebDavConfigRepository(store);
      final key = Uint8List.fromList(List.filled(32, 7));
      await repo.savePersonalKey(key);
      expect(await repo.requirePersonalKey(), key);
    });
  });

  group('family vault', () {
    test('saveFamilyKey stores entropy and clearFamilyKey removes it', () async {
      final store = InMemoryKeyValueStore();
      final repo = WebDavConfigRepository(store);
      final key = Uint8List.fromList(List.filled(32, 3));
      final entropy = Uint8List.fromList(List.filled(16, 9));
      await repo.saveFamilyKey(key, entropy: entropy);
      expect(await repo.loadFamilyKey(), key);
      expect(await repo.loadFamilyEntropy(), entropy);
      await repo.clearFamilyKey();
      expect(await repo.loadFamilyKey(), isNull);
      expect(await repo.loadFamilyEntropy(), isNull);
    });

    test('personal entropy round-trips and clear removes it', () async {
      final store = InMemoryKeyValueStore();
      final repo = WebDavConfigRepository(store);
      final entropy = Uint8List.fromList(List.filled(16, 4));
      await repo.savePersonalEntropy(entropy);
      expect(await repo.loadPersonalEntropy(), entropy);
      await repo.clearPersonalEntropy();
      expect(await repo.loadPersonalEntropy(), isNull);
    });
  });
}
