import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:mockito/mockito.dart';

import 'webdav_client_test.mocks.dart';

void main() {
  const abandonAbout =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  group('KineticVault mnemonic', () {
    test('all-zero entropy is the BIP-39 abandon/about mnemonic', () async {
      final words = await KineticVault.mnemonicFromEntropy(
        Uint8List(16),
      );
      expect(words.join(' '), abandonAbout);
    });

    test('deriveAesKey matches BIP-39 seed prefix for abandon/about', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      expect(key.length, 32);
      // Empty BIP-39 passphrase; Trezor vectors use passphrase "TREZOR".
      expect(key.sublist(0, 8), hexDecode('5eb00bbddcf06908'));
    });

    test('deriveAesKey is deterministic', () async {
      final a = await KineticVault.deriveAesKey(abandonAbout);
      final b = await KineticVault.deriveAesKey(abandonAbout);
      expect(a, b);
    });

    test('whitespace and case are ignored', () async {
      final a = await KineticVault.deriveAesKey(abandonAbout);
      final b = await KineticVault.deriveAesKey(
        '  ABANDON abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon ABOUT  ',
      );
      expect(a, b);
    });

    test('bad checksum is rejected', () async {
      expect(
        () => KineticVault.deriveAesKey(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown word is rejected', () async {
      expect(
        () => KineticVault.parseMnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon xyzzy',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrong word count is rejected', () async {
      expect(
        () => KineticVault.parseMnemonic('abandon about'),
        throwsA(isA<FormatException>()),
      );
    });

    test('generateMnemonic is 12 valid words with unique keys', () async {
      final a = await KineticVault.generateMnemonic(random: Random(1));
      final b = await KineticVault.generateMnemonic(random: Random(2));
      expect(a.length, 12);
      expect(await KineticVault.isValidMnemonic(a.join(' ')), isTrue);
      expect(await KineticVault.isValidMnemonic(b.join(' ')), isTrue);
      final keyA = await KineticVault.deriveAesKey(a.join(' '));
      final keyB = await KineticVault.deriveAesKey(b.join(' '));
      expect(keyA, isNot(equals(keyB)));
    });

    test('kBip39English has 2048 unique words', () {
      expect(kBip39English.length, 2048);
      expect(kBip39English.toSet().length, 2048);
      expect(kBip39English.first, 'abandon');
      expect(kBip39English.last, 'zoo');
    });
  });

  group('KineticVault quiz and keys', () {
    test('pickQuizIndices returns sorted unique indices', () {
      final indices = KineticVault.pickQuizIndices(random: Random(7));
      expect(indices.length, 3);
      expect(indices.toSet().length, 3);
      expect(indices, equals([...indices]..sort()));
      expect(indices.every((i) => i >= 0 && i < 12), isTrue);
    });

    test('quizMatches requires exact words', () {
      final words = abandonAbout.split(' ');
      const indices = [0, 5, 11];
      expect(
        KineticVault.quizMatches(
          mnemonic: words,
          indices: indices,
          answers: ['abandon', 'abandon', 'about'],
        ),
        isTrue,
      );
      expect(
        KineticVault.quizMatches(
          mnemonic: words,
          indices: indices,
          answers: ['abandon', 'wrong', 'about'],
        ),
        isFalse,
      );
    });

    test('equalKeys is constant-time equality', () {
      final a = Uint8List.fromList(List.filled(32, 1));
      final b = Uint8List.fromList(List.filled(32, 1));
      final c = Uint8List.fromList(List.filled(32, 2));
      expect(KineticVault.equalKeys(a, b), isTrue);
      expect(KineticVault.equalKeys(a, c), isFalse);
      expect(KineticVault.equalKeys(a, Uint8List(16)), isFalse);
    });
  });

  group('KineticVault canary and kvault file', () {
    test('canary round-trips with the derived key', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final blob = await KineticVault.sealCanary(key);
      expect(await KineticVault.openCanary(blob, key), isTrue);
      final other = KineticEncryption.generatePersonalKey();
      expect(await KineticVault.openCanary(blob, other), isFalse);
    });

    test('wrap/unwrap backup hides plaintext without the key', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final inner = Uint8List.fromList(utf8.encode('{"hello":"vault"}'));
      final file = await KineticVault.wrapBackup(
        plaintext: inner,
        key: key,
        usernameHint: 'alice',
      );
      final asText = utf8.decode(file);
      expect(asText, contains('"format":"kvault"'));
      expect(asText, isNot(contains('hello')));
      expect(asText, isNot(contains(abandonAbout)));

      final recovered = await KineticVault.unwrapBackup(file, key);
      expect(recovered, inner);
    });

    test('unwrapBackup throws on wrong key', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final file = await KineticVault.wrapBackup(
        plaintext: Uint8List.fromList([1, 2, 3]),
        key: key,
      );
      final wrong = KineticEncryption.generatePersonalKey();
      expect(
        () => KineticVault.unwrapBackup(file, wrong),
        throwsA(isA<FormatException>()),
      );
    });

    test('unwrapBackup rejects kbak2-shaped JSON', () {
      final fake = utf8.encode(
        jsonEncode({
          'version': 3,
          'personalKey': 'abc',
          'database': 'def',
        }),
      );
      expect(
        () => KineticVault.unwrapBackup(
          Uint8List.fromList(fake),
          Uint8List(32),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('KineticVaultRemote', () {
    late MockClient mockHttp;
    late WebDavClient client;

    setUp(() {
      mockHttp = MockClient();
      client = WebDavClient(
        baseUrl: 'https://dav.example.com',
        username: 'alice',
        password: 's3cret',
        httpClient: mockHttp,
      );
    });

    test('probe returns missing on 404', () async {
      when(mockHttp.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      final status = await KineticVaultRemote.probe(
        client: client,
        username: 'alice',
        key: Uint8List(32),
      );
      expect(status, VaultMetaStatus.missing);
    });

    test('probe returns unlocked when canary decrypts', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final blob = await KineticVault.sealCanary(key);
      when(mockHttp.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response.bytes(blob, 200),
      );

      final status = await KineticVaultRemote.probe(
        client: client,
        username: 'alice',
        key: key,
      );
      expect(status, VaultMetaStatus.unlocked);
    });

    test('probe returns wrongPhrase when decrypt fails', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final blob = await KineticVault.sealCanary(key);
      when(mockHttp.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response.bytes(blob, 200),
      );

      final status = await KineticVaultRemote.probe(
        client: client,
        username: 'alice',
        key: KineticEncryption.generatePersonalKey(),
      );
      expect(status, VaultMetaStatus.wrongPhrase);
    });
  });

  group('KineticVault family', () {
    test('entropyFromMnemonic round-trips all-zero entropy', () async {
      final words = await KineticVault.mnemonicFromEntropy(Uint8List(16));
      final entropy = await KineticVault.entropyFromMnemonic(words);
      expect(entropy, Uint8List(16));
    });

    test('fingerprint is 4 uppercase hex chars', () async {
      final key = await KineticVault.deriveAesKey(abandonAbout);
      final fp = await KineticVault.fingerprint(key);
      expect(fp.length, 4);
      expect(fp, equals(fp.toUpperCase()));
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(fp), isTrue);
    });

    test('family QR v2 reconstructs the same AES key', () async {
      final created = await KineticVault.createMnemonic(random: Random(3));
      final key = await KineticVault.deriveAesKey(created.words.join(' '));
      final qr = KineticVault.exportFamilyEntropyQrPayload(
        entropy: created.entropy,
        serverUrl: 'https://dav.example.com',
        username: 'alice',
      );
      expect(qr, contains('"v":2'));
      expect(qr, isNot(contains('pw')));
      expect(qr, isNot(contains(base64.encode(key))));

      final imported = await KineticVault.importFamilyQrPayload(qr);
      expect(imported.familyKey, key);
      expect(imported.entropy, created.entropy);
      expect(imported.username, 'alice');
    });

    test('family recovery wrap/unwrap uses the personal key', () async {
      final personal = await KineticVault.deriveAesKey(abandonAbout);
      final created = await KineticVault.createMnemonic(random: Random(4));
      final familyKey = await KineticVault.deriveAesKey(created.words.join(' '));
      final blob = await KineticVault.wrapFamilyRecovery(
        familyKey: familyKey,
        entropy: created.entropy,
        personalKey: personal,
      );
      final recovered = await KineticVault.unwrapFamilyRecovery(blob, personal);
      expect(recovered.familyKey, familyKey);
      expect(recovered.entropy, created.entropy);
    });

    test('legacy v1 family QR still imports the raw key', () async {
      final key = KineticEncryption.generateFamilyKey();
      final qr = KineticEncryption.exportFamilyKeyQrPayload(
        key,
        'https://dav.example.com',
        'bob',
      );
      final imported = await KineticVault.importFamilyQrPayload(qr);
      expect(imported.familyKey, key);
      expect(imported.entropy, isNull);
    });
  });
}

Uint8List hexDecode(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
