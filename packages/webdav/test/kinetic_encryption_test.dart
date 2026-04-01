import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

void main() {
  group('KineticEncryption', () {
    test('generatePersonalKey returns 32 bytes', () {
      final key = KineticEncryption.generatePersonalKey();
      expect(key.length, equals(32));
    });

    test('generatePersonalKey returns different values each call', () {
      final a = KineticEncryption.generatePersonalKey();
      final b = KineticEncryption.generatePersonalKey();
      expect(a, isNot(equals(b)));
    });

    test('encrypt + decrypt round-trips correctly', () async {
      final key = KineticEncryption.generatePersonalKey();
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 42, 99]);

      final blob = await KineticEncryption.encrypt(plaintext, key);
      final recovered = await KineticEncryption.decrypt(blob, key);

      expect(recovered, equals(plaintext));
    });

    test(
        'two encryptions of the same plaintext produce different blobs (nonce freshness)',
        () async {
      final key = KineticEncryption.generatePersonalKey();
      final plaintext = Uint8List.fromList([1, 2, 3]);

      final blob1 = await KineticEncryption.encrypt(plaintext, key);
      final blob2 = await KineticEncryption.encrypt(plaintext, key);

      expect(blob1, isNot(equals(blob2)));
    });

    test('decrypt with wrong key throws', () async {
      final key = KineticEncryption.generatePersonalKey();
      final wrongKey = KineticEncryption.generatePersonalKey();
      final blob =
          await KineticEncryption.encrypt(Uint8List.fromList([1, 2, 3]), key);

      expect(
        () => KineticEncryption.decrypt(blob, wrongKey),
        throwsA(anything),
      );
    });

    test('deriveFamilyKey returns 32 bytes', () async {
      final key = await KineticEncryption.deriveFamilyKey('mySecretPassword');
      expect(key.length, equals(32));
    });

    test('deriveFamilyKey is deterministic', () async {
      final a = await KineticEncryption.deriveFamilyKey('password123');
      final b = await KineticEncryption.deriveFamilyKey('password123');
      expect(a, equals(b));
    });

    test('deriveFamilyKey differs for different passwords', () async {
      final a = await KineticEncryption.deriveFamilyKey('password123');
      final b = await KineticEncryption.deriveFamilyKey('password456');
      expect(a, isNot(equals(b)));
    });

    group('recovery JSON', () {
      test('export + import round-trips correctly', () {
        final key = KineticEncryption.generatePersonalKey();
        final json = KineticEncryption.exportRecoveryJson(key, 'alice');
        final recovered = KineticEncryption.importRecoveryJson(json);
        expect(recovered, equals(key));
      });

      test('exported JSON contains usernameHint', () {
        final key = KineticEncryption.generatePersonalKey();
        final json = KineticEncryption.exportRecoveryJson(key, 'bob');
        expect(json, contains('bob'));
      });

      test('importRecoveryJson throws on bad JSON', () {
        expect(
          () => KineticEncryption.importRecoveryJson('not-json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('importRecoveryJson throws on wrong version', () {
        expect(
          () => KineticEncryption.importRecoveryJson(
            '{"version":99,"usernameHint":"x","personalKey":"aGVsbG8="}',
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
