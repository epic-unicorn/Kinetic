import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens an on-disk Drift database encrypted with SQLite3MultipleCiphers.
QueryExecutor openEncryptedDatabase({
  required String name,
  Future<Directory> Function() databaseDirectory = getApplicationDocumentsDirectory,
  String secureStorageKey = 'kinetic_kids_db_encryption_key',
}) {
  return LazyDatabase(() async {
    final key = await _DbEncryptionKeyStore(secureStorageKey).obtain();
    final dir = await databaseDirectory();
    final plaintext = File(p.join(dir.path, '$name.sqlite'));
    final encrypted = File(p.join(dir.path, '$name.encrypted.sqlite'));

    return NativeDatabase.createInBackground(
      encrypted,
      isolateSetup: () async {
        await _migratePlaintextIfNeeded(
          plaintextPath: plaintext.path,
          encryptedPath: encrypted.path,
          key: key,
        );
      },
      setup: (rawDb) {
        final ciphers = rawDb.select('PRAGMA cipher;');
        if (ciphers.isEmpty) {
          throw UnsupportedError(
            'SQLite3MultipleCiphers is not available. '
            'Set hooks.user_defines.sqlite3.source to sqlite3mc in the '
            'workspace root pubspec.yaml.',
          );
        }
        rawDb.execute("PRAGMA key = '${_escape(key)}'");
        rawDb.execute('SELECT count(*) FROM sqlite_master');
      },
    );
  });
}

Future<void> _migratePlaintextIfNeeded({
  required String plaintextPath,
  required String encryptedPath,
  required String key,
}) async {
  final existing = File(plaintextPath);
  final encrypted = File(encryptedPath);
  if (!await existing.exists() || await encrypted.exists()) {
    return;
  }

  final tmp = File('$encryptedPath.tmp');
  if (await tmp.exists()) {
    await tmp.delete();
  }

  final plaintextDb = sqlite3.open(plaintextPath)
    ..execute("VACUUM INTO '${_escape(tmp.path)}'");
  plaintextDb.close();

  final encryptedDb = sqlite3.open(tmp.path);
  encryptedDb.execute("PRAGMA rekey = '${_escape(key)}'");
  encryptedDb.close();

  await tmp.rename(encryptedPath);
  await existing.delete();
}

String _escape(String source) => source.replaceAll("'", "''");

class _DbEncryptionKeyStore {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final String storageKey;
  final FlutterSecureStorage _storage;

  _DbEncryptionKeyStore(this.storageKey)
      : _storage = const FlutterSecureStorage(
          aOptions: _androidOptions,
          iOptions: _iosOptions,
        );

  Future<String> obtain() async {
    final existing = await _storage.read(
      key: storageKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bytes = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    final encoded = base64UrlEncode(bytes);
    await _storage.write(
      key: storageKey,
      value: encoded,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    return encoded;
  }
}
