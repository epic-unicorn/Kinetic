import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_core/kinetic_core.dart';

import '../helpers/in_memory_key_store.dart';

void main() {
  group('IdentityService', () {
    late InMemoryKeyStore keyStore;
    late IdentityService sut;

    setUp(() {
      keyStore = InMemoryKeyStore();
      sut = IdentityService(store: keyStore);
    });

    test('creates a new identity on first call', () async {
      final identity = await sut.getOrCreateIdentity();

      expect(identity.deviceId, isNotEmpty);
      expect(identity.publicKeyBytes, hasLength(32));
    });

    test('public key base64 is valid and decodes to 32 bytes', () async {
      final identity = await sut.getOrCreateIdentity();
      final decoded = base64Decode(identity.publicKeyBase64);
      expect(decoded, hasLength(32));
    });

    test('returns identical identity on repeated calls', () async {
      final first = await sut.getOrCreateIdentity();
      final second = await sut.getOrCreateIdentity();

      expect(second.deviceId, equals(first.deviceId));
      expect(second.publicKeyBase64, equals(first.publicKeyBase64));
    });

    test('persists device ID and seed in the key store', () async {
      await sut.getOrCreateIdentity();

      expect(keyStore.snapshot['kinetic_device_id'], isNotNull);
      expect(keyStore.snapshot['kinetic_ed25519_seed'], isNotNull);
    });

    test('restores identity from persisted seed via a fresh service instance',
        () async {
      final original = await sut.getOrCreateIdentity();

      final restored = IdentityService(store: keyStore);
      final restoredIdentity = await restored.getOrCreateIdentity();

      expect(restoredIdentity.deviceId, equals(original.deviceId));
      expect(
          restoredIdentity.publicKeyBase64, equals(original.publicKeyBase64));
    });

    test('different stores produce different identities', () async {
      final id1 = await sut.getOrCreateIdentity();
      final id2 = await IdentityService(store: InMemoryKeyStore())
          .getOrCreateIdentity();

      expect(id2.deviceId, isNot(equals(id1.deviceId)));
      expect(id2.publicKeyBase64, isNot(equals(id1.publicKeyBase64)));
    });

    group('sign / verify', () {
      test('valid signature verifies successfully', () async {
        final identity = await sut.getOrCreateIdentity();
        final data = utf8.encode('Hello, Kinetic!');

        final sigBytes = await sut.sign(data);
        final valid = await sut.verify(
          data: data,
          signatureBytes: sigBytes,
          publicKeyBytes: identity.publicKeyBytes,
        );

        expect(valid, isTrue);
      });

      test('signature fails for tampered data', () async {
        final identity = await sut.getOrCreateIdentity();
        final data = utf8.encode('Original message');
        final tampered = utf8.encode('Tampered message');

        final sigBytes = await sut.sign(data);
        final valid = await sut.verify(
          data: tampered,
          signatureBytes: sigBytes,
          publicKeyBytes: identity.publicKeyBytes,
        );

        expect(valid, isFalse);
      });

      test('signature fails for wrong public key', () async {
        final data = utf8.encode('Hello');
        final sigBytes = await sut.sign(data);

        final otherIdentity = await IdentityService(store: InMemoryKeyStore())
            .getOrCreateIdentity();

        final valid = await sut.verify(
          data: data,
          signatureBytes: sigBytes,
          publicKeyBytes: otherIdentity.publicKeyBytes,
        );

        expect(valid, isFalse);
      });
    });

    group('clearIdentity', () {
      test('removes keys from store', () async {
        await sut.getOrCreateIdentity();
        await sut.clearIdentity();

        expect(keyStore.snapshot['kinetic_device_id'], isNull);
        expect(keyStore.snapshot['kinetic_ed25519_seed'], isNull);
      });

      test('generates a new identity after clear', () async {
        final original = await sut.getOrCreateIdentity();
        await sut.clearIdentity();
        final regenerated = await sut.getOrCreateIdentity();

        expect(regenerated.deviceId, isNot(equals(original.deviceId)));
        expect(regenerated.publicKeyBase64,
            isNot(equals(original.publicKeyBase64)));
      });
    });
  });
}
