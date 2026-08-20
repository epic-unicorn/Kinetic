import 'package:drift/drift.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../sync/webdav_config_repository.dart';
import 'family_vault_sync.dart';

/// Marks personal (not family-shared) items so the next sync re-encrypts them
/// after the vault key changes.
Future<void> markPersonalItemsDirty(AppDatabase db) async {
  await (db.update(db.personalTasks)..where(
        (t) => t.syncState.equals('clean') | t.syncState.isNull(),
      ))
      .write(const PersonalTasksCompanion(syncState: Value('dirty')));
  await (db.update(db.personalNotes)..where(
        (n) =>
            n.isShared.equals(false) &
            (n.syncState.equals('clean') | n.syncState.isNull()),
      ))
      .write(const PersonalNotesCompanion(syncState: Value('dirty')));
}

/// Overwrites `vault.meta` and re-wraps `family.key.enc` with the new personal
/// key. No-op when WebDAV is not configured or the server is unreachable.
Future<void> rewriteRemoteAfterPersonalKeyRotation(
  WebDavConfigRepository configRepo,
) async {
  final config = await configRepo.load();
  final personal = await configRepo.loadPersonalKeyBytes();
  if (config == null || personal == null) return;
  final client = WebDavClient(
    baseUrl: config.serverUrl,
    username: config.username,
    password: config.password,
  );
  try {
    await KineticVaultRemote.writeMeta(
      client: client,
      username: config.username,
      key: personal,
    );
    await FamilyVaultSync.pushIfPossible(configRepo);
  } catch (_) {
    // Offline is fine; the next successful sync can write the canary.
  } finally {
    client.dispose();
  }
}
