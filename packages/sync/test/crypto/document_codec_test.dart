import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

void main() {
  // Use a fixed 32-byte key for all tests — deterministic but realistic.
  final meshKey = List<int>.generate(32, (i) => i + 1);

  group('DocumentCodec', () {
    late DocumentCodec sut;

    setUp(() => sut = DocumentCodec());

    // -------------------------------------------------------------------------
    // Encrypt + decrypt round-trips
    // -------------------------------------------------------------------------

    test('round-trip preserves all payload fields', () async {
      final doc = {
        '_id': 'task:abc123',
        'type': 'task',
        'title': 'Clean Room',
        'xpReward': 50,
        'status': 'pending',
      };

      final enc = await sut.encrypt(doc, meshKey);
      final dec = await sut.decrypt(enc, meshKey);

      expect(dec['_id'], equals('task:abc123'));
      expect(dec['title'], equals('Clean Room'));
      expect(dec['xpReward'], equals(50));
      expect(dec['status'], equals('pending'));
    });

    test('round-trip preserves _rev when present', () async {
      final doc = {
        '_id': 'plan:001',
        '_rev': '3-abc',
        'name': 'Our Family',
        'crdtVersion': 7,
      };

      final enc = await sut.encrypt(doc, meshKey);
      final dec = await sut.decrypt(enc, meshKey);

      expect(dec['_rev'], equals('3-abc'));
      expect(dec['name'], equals('Our Family'));
      expect(dec['crdtVersion'], equals(7));
    });

    test('round-trip preserves _deleted tombstones', () async {
      final doc = {
        '_id': 'task:dead',
        '_rev': '2-xyz',
        '_deleted': true,
        'wasTitle': 'Old chore',
      };

      final enc = await sut.encrypt(doc, meshKey);
      final dec = await sut.decrypt(enc, meshKey);

      expect(dec['_deleted'], isTrue);
      expect(dec['_id'], equals('task:dead'));
    });

    test('encrypted document hides payload fields', () async {
      final doc = {'_id': 'task:secret', 'title': 'Hidden', 'xp': 100};
      final enc = await sut.encrypt(doc, meshKey);

      expect(enc.containsKey('title'), isFalse);
      expect(enc.containsKey('xp'), isFalse);
    });

    test('encrypted document contains enc=1, iv, ct', () async {
      final doc = {'_id': 'task:x', 'title': 'Test'};
      final enc = await sut.encrypt(doc, meshKey);

      expect(enc['enc'], equals(1));
      expect(enc['iv'], isA<String>());
      expect(enc['ct'], isA<String>());
    });

    test('nonce decodes to exactly 12 bytes', () async {
      final enc = await sut.encrypt({'_id': 'x', 'v': 1}, meshKey);
      final iv = base64Decode(enc['iv'] as String);
      expect(iv, hasLength(12));
    });

    test('ciphertext includes 16-byte GCM tag (ct.length >= 16)', () async {
      final enc = await sut.encrypt({'_id': 'x', 'value': 'y'}, meshKey);
      final ctBytes = base64Decode(enc['ct'] as String);
      expect(ctBytes.length, greaterThanOrEqualTo(16));
    });

    test(
      'successive encryptions of the same doc produce different IVs',
      () async {
        final doc = {'_id': 'task:nonce', 'v': 1};
        final enc1 = await sut.encrypt(doc, meshKey);
        final enc2 = await sut.encrypt(doc, meshKey);
        expect(enc1['iv'], isNot(equals(enc2['iv'])));
      },
    );

    // -------------------------------------------------------------------------
    // Documents without enc flag pass through
    // -------------------------------------------------------------------------

    test(
      'plaintext document (no enc field) passes through decrypt unchanged',
      () async {
        final plain = {
          '_id': 'sentinel:hub',
          '_rev': '1-aaa',
          'type': 'hub_sentinel',
        };
        final result = await sut.decrypt(plain, meshKey);

        expect(result, equals(plain));
      },
    );

    // -------------------------------------------------------------------------
    // Auth-tag verification (tamper detection)
    // -------------------------------------------------------------------------

    test('decrypt throws on tampered ciphertext', () async {
      final doc = {'_id': 'task:tamper', 'secret': 'data'};
      final enc = await sut.encrypt(doc, meshKey);

      // Flip a byte in the middle of the ct blob.
      final ctBytes = base64Decode(enc['ct'] as String);
      ctBytes[ctBytes.length ~/ 2] ^= 0xFF;
      final tampered = Map<String, dynamic>.from(enc)
        ..['ct'] = base64Encode(ctBytes);

      await expectLater(
        () => sut.decrypt(tampered, meshKey),
        throwsA(anything),
      );
    });

    test('decrypt throws with wrong mesh key', () async {
      final doc = {'_id': 'task:wrongkey', 'v': 1};
      final enc = await sut.encrypt(doc, meshKey);

      final wrongKey = List<int>.generate(32, (_) => 0xFF);
      await expectLater(() => sut.decrypt(enc, wrongKey), throwsA(anything));
    });

    test('decrypt throws FormatException on truncated ct', () async {
      final enc = {
        '_id': 'x',
        'enc': 1,
        'iv': base64Encode(List.filled(12, 0)),
        'ct': base64Encode([1, 2, 3]), // < 16 bytes → FormatException
      };
      await expectLater(
        () => sut.decrypt(enc, meshKey),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
