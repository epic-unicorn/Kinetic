import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_core/kinetic_core.dart';

import '../helpers/in_memory_key_store.dart';

void main() {
  group('PairingService', () {
    late IdentityService identityService;
    late PairingService sut;

    setUp(() {
      identityService = IdentityService(store: InMemoryKeyStore());
      sut = PairingService(identityService: identityService);
    });

    test('generatePairingPayload returns valid base64', () async {
      final payload = await sut.generatePairingPayload(
        deviceLabel: 'Sarah',
        role: MemberRole.parent,
      );
      expect(() => base64Decode(payload), returnsNormally);
    });

    test('round-trip preserves all fields', () async {
      final identity = await identityService.getOrCreateIdentity();

      final payload = await sut.generatePairingPayload(
        deviceLabel: 'Sarah',
        role: MemberRole.parent,
      );
      final parsed = sut.parsePairingPayload(payload);

      expect(parsed.deviceId, equals(identity.deviceId));
      expect(parsed.publicKeyBase64, equals(identity.publicKeyBase64));
      expect(parsed.label, equals('Sarah'));
      expect(parsed.role, equals(MemberRole.parent));
      expect(parsed.meshKeyBase64, isNotEmpty);
    });

    test('mesh key deserialises to exactly 32 bytes', () async {
      final payload = await sut.generatePairingPayload(
        deviceLabel: 'Dad',
        role: MemberRole.parent,
      );
      final parsed = sut.parsePairingPayload(payload);
      expect(base64Decode(parsed.meshKeyBase64), hasLength(32));
    });

    test('successive payloads carry unique mesh keys', () async {
      final p1 = sut.parsePairingPayload(
        await sut.generatePairingPayload(
            deviceLabel: 'Parent 1', role: MemberRole.parent),
      );
      final p2 = sut.parsePairingPayload(
        await sut.generatePairingPayload(
            deviceLabel: 'Parent 2', role: MemberRole.parent),
      );
      expect(p1.meshKeyBase64, isNot(equals(p2.meshKeyBase64)));
    });

    test('child role is preserved through round-trip', () async {
      final payload = await sut.generatePairingPayload(
        deviceLabel: 'Alex',
        role: MemberRole.child,
      );
      final parsed = sut.parsePairingPayload(payload);
      expect(parsed.role, equals(MemberRole.child));
    });

    test('toFamilyMember maps all fields correctly', () async {
      final identity = await identityService.getOrCreateIdentity();
      final payload = await sut.generatePairingPayload(
        deviceLabel: 'Emma',
        role: MemberRole.child,
      );
      final member = sut.parsePairingPayload(payload).toFamilyMember();

      expect(member.id, equals(identity.deviceId));
      expect(member.name, equals('Emma'));
      expect(member.role, equals(MemberRole.child));
      expect(member.publicKeyBase64, equals(identity.publicKeyBase64));
    });

    group('error handling', () {
      test('throws FormatException for random string', () {
        expect(
          () => sut.parsePairingPayload('not-valid-base64!@#\$'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for unsupported version', () {
        final bad = base64Encode(utf8.encode('{"v":99,"id":"x","pk":"y",'
            '"mk":"z","role":"parent","label":"X"}'));
        expect(
          () => sut.parsePairingPayload(bad),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for truncated payload', () {
        expect(
          () => sut.parsePairingPayload(base64Encode(utf8.encode('{'))),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
