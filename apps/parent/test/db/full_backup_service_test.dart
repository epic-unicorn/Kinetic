import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:parent/db/full_backup_service.dart';

import '../helpers/test_database.dart';

void main() {
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('kvault export has no raw key and restores with the phrase', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final key = await KineticVault.deriveAesKey(phrase);

    final bytes = await FullBackupService.exportVaultToBytes(
      db,
      key,
      usernameHint: 'alice',
      currentThemeName: 'sand',
    );
    final text = utf8.decode(bytes);
    expect(text, contains('"format":"kvault"'));
    expect(text, isNot(contains('personalKey')));
    expect(text, isNot(contains(base64.encode(key))));

    final db2 = createTestDatabase();
    addTearDown(db2.close);
    await FullBackupService.importVaultFromBytes(db2, bytes, key);

    final wrong = KineticEncryption.generatePersonalKey();
    expect(
      () => FullBackupService.importVaultFromBytes(db2, bytes, wrong),
      throwsA(isA<FormatException>()),
    );
  });
}
