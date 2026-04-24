import 'dart:convert';
import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:uuid/uuid.dart';

import '../settings/models/enrolled_kid.dart';

/// Secure-storage keys for WebDAV configuration.
const _kServerUrl = 'kinetic_webdav_server_url';
const _kUsername = 'kinetic_webdav_username';
const _kPassword = 'kinetic_webdav_password';
const _kPersonalKey = 'kinetic_webdav_personal_key';
const _kFamilyKey = 'kinetic_webdav_family_key';
const _kParentId = 'kinetic_webdav_parent_id';
const _kEnrolledKids = 'kinetic_enrolled_kids';
const _kPartnerPaired = 'kinetic_partner_paired';

/// Persists and loads [SyncConfig] from [SecureKeyValueStore].
///
/// Keys are stored individually so the password can be updated independently
/// of the encryption keys (e.g. after a WebDAV password change + re-derive).
class WebDavConfigRepository {
  final SecureKeyValueStore _store;

  WebDavConfigRepository(this._store);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns the stored [SyncConfig], or null if the user has not yet
  /// configured WebDAV.
  Future<SyncConfig?> load() async {
    final serverUrl = await _store.read(key: _kServerUrl);
    final username = await _store.read(key: _kUsername);
    final password = await _store.read(key: _kPassword);
    final personalKeyBase64 = await _store.read(key: _kPersonalKey);

    if (serverUrl == null ||
        username == null ||
        password == null ||
        personalKeyBase64 == null) {
      return null;
    }

    final personalKeyBytes = Uint8List.fromList(
      base64.decode(personalKeyBase64),
    );

    final familyKeyBase64 = await _store.read(key: _kFamilyKey);
    final familyKeyBytes = familyKeyBase64 != null
        ? Uint8List.fromList(base64.decode(familyKeyBase64))
        : null;

    // parentId may be absent for existing installs — treated as null here;
    // the setup screen generates and persists one on the next save.
    final parentId = await _store.read(key: _kParentId) ?? '';

    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      parentId: parentId,
      personalKeyBytes: personalKeyBytes,
      familyKeyBytes: familyKeyBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Persists a full [SyncConfig] to secure storage.
  Future<void> save(SyncConfig config) async {
    await _store.write(key: _kServerUrl, value: config.serverUrl);
    await _store.write(key: _kUsername, value: config.username);
    await _store.write(key: _kPassword, value: config.password);
    await _store.write(key: _kParentId, value: config.parentId);
    await _store.write(
      key: _kPersonalKey,
      value: base64.encode(config.personalKeyBytes),
    );
    if (config.familyKeyBytes != null) {
      await _store.write(
        key: _kFamilyKey,
        value: base64.encode(config.familyKeyBytes!),
      );
    }
  }

  /// Updates only the password in secure storage.
  ///
  /// The family key is intentionally left unchanged — it is independent of
  /// the WebDAV password and is shared explicitly between parents.
  Future<void> updatePassword(String newPassword) async {
    await _store.write(key: _kPassword, value: newPassword);
  }

  /// Stores a new family key without touching any other config fields.
  ///
  /// Use this after importing a family key from a partner parent.
  Future<void> saveFamilyKey(Uint8List familyKey) async {
    await _store.write(key: _kFamilyKey, value: base64.encode(familyKey));
  }

  /// Ensures a family key exists in secure storage, generating one if absent.
  ///
  /// Call this before generating a kids enrollment QR — the key is required
  /// even when no partner is paired yet (the family key is shared later).
  /// Returns the (possibly newly generated) key bytes.
  Future<Uint8List> ensureFamilyKey() async {
    final existing = await _store.read(key: _kFamilyKey);
    if (existing != null) {
      return Uint8List.fromList(base64.decode(existing));
    }
    final newKey = KineticEncryption.generateFamilyKey();
    await _store.write(key: _kFamilyKey, value: base64.encode(newKey));
    return newKey;
  }

  /// Stores a new personal key without touching any other config fields.
  ///
  /// Use this when importing a personal key backup, independent of WebDAV.
  Future<void> savePersonalKey(Uint8List personalKey) async {
    await _store.write(key: _kPersonalKey, value: base64.encode(personalKey));
  }

  /// Returns just the personal key bytes from secure storage, or null if not yet configured.
  Future<Uint8List?> loadPersonalKeyBytes() async {
    final base64str = await _store.read(key: _kPersonalKey);
    if (base64str == null) return null;
    return Uint8List.fromList(base64.decode(base64str));
  }

  /// Returns the personal key, generating and persisting a new one if absent.
  ///
  /// This allows the backup/restore flow to work without requiring WebDAV to
  /// be configured first.  The key is stored under the same secure-storage
  /// slot used by the WebDAV config so it is automatically re-used when the
  /// user later sets up WebDAV sync.
  Future<Uint8List> ensurePersonalKey() async {
    final existing = await loadPersonalKeyBytes();
    if (existing != null) return existing;
    final newKey = KineticEncryption.generatePersonalKey();
    await savePersonalKey(newKey);
    return newKey;
  }

  /// Removes the family key without touching any other config fields.
  ///
  /// Call this when leaving the family pairing.
  Future<void> clearFamilyKey() async {
    await _store.delete(key: _kFamilyKey);
    await _store.delete(key: _kPartnerPaired);
  }

  /// Marks whether the user has explicitly paired with a partner.
  ///
  /// Set to true after sharing or scanning a family key QR with a partner.
  /// Distinct from [familyKeyBytes] which may also exist for kids-only setups.
  Future<void> setPartnerPaired(bool paired) async {
    await _store.write(key: _kPartnerPaired, value: paired ? '1' : '0');
  }

  /// Returns true if the user has explicitly paired with a partner.
  Future<bool> isPartnerPaired() async {
    final val = await _store.read(key: _kPartnerPaired);
    return val == '1';
  }

  // ---------------------------------------------------------------------------
  // Enrolled Kids
  // ---------------------------------------------------------------------------

  /// Returns the list of kids enrolled by this parent device.
  Future<List<EnrolledKid>> loadEnrolledKids() async {
    final json = await _store.read(key: _kEnrolledKids);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => EnrolledKid.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a new kid with [name] to the enrolled list and returns the
  /// [EnrolledKid] that was created (including its generated ID).
  Future<EnrolledKid> addEnrolledKid(String name) async {
    final kid = EnrolledKid(
      id: const Uuid().v4(),
      name: name,
      enrolledAt: DateTime.now().toUtc(),
    );
    final kids = await loadEnrolledKids();
    kids.add(kid);
    await _writeEnrolledKids(kids);
    return kid;
  }

  /// Removes a kid by ID from the enrolled list.
  Future<void> removeEnrolledKid(String kidId) async {
    final kids = await loadEnrolledKids();
    kids.removeWhere((k) => k.id == kidId);
    await _writeEnrolledKids(kids);
  }

  /// Replaces the entire enrolled-kids list (used during backup restore).
  Future<void> restoreEnrolledKids(List<EnrolledKid> kids) =>
      _writeEnrolledKids(kids);

  Future<void> _writeEnrolledKids(List<EnrolledKid> kids) async {
    final json = jsonEncode(kids.map((k) => k.toJson()).toList());
    await _store.write(key: _kEnrolledKids, value: json);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Clears all WebDAV configuration from secure storage.
  Future<void> clear() async {
    await _store.delete(key: _kServerUrl);
    await _store.delete(key: _kUsername);
    await _store.delete(key: _kPassword);
    await _store.delete(key: _kParentId);
    await _store.delete(key: _kPersonalKey);
    await _store.delete(key: _kFamilyKey);
    await _store.delete(key: _kPartnerPaired);
  }
}
