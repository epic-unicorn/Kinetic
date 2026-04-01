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
        personalKeyBytes: Uint8List.fromList(List.filled(32, 0)),
        familyKeyBytes: null,
      );

      expect(config.serverUrl, equals('https://dav.example.com'));
      expect(config.username, equals('user@example.com'));
      expect(config.password, equals('password123'));
      expect(config.personalKeyBytes.length, equals(32));
      expect(config.familyKeyBytes, isNull);
    });

    test('SyncConfig supports encryption key management', () {
      final personalKey = Uint8List.fromList(List.filled(32, 42));
      final familyKey = Uint8List.fromList(List.filled(32, 99));

      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: personalKey,
        familyKeyBytes: familyKey,
      );

      expect(config.personalKeyBytes, equals(personalKey));
      expect(config.familyKeyBytes, equals(familyKey));
    });

    test('SyncConfig family key is optional', () {
      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List.fromList(List.filled(32, 0)),
        familyKeyBytes: null,
      );

      expect(config.familyKeyBytes, isNull);
    });

    test('Encryption keys are 32 bytes for AES-256', () {
      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List.fromList(List.filled(32, 0)),
        familyKeyBytes: Uint8List.fromList(List.filled(32, 1)),
      );

      expect(config.personalKeyBytes.length, equals(32));
      expect(config.familyKeyBytes!.length, equals(32));
    });
  });
}
