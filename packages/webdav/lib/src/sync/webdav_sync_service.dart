import 'dart:convert';
import 'dart:typed_data';

import '../encryption/kinetic_encryption.dart';
import '../ical/ical_note.dart';
import '../ical/ical_serializer.dart';
import '../ical/ical_task.dart';
import '../sync_config.dart';
import '../webdav_client.dart';

/// Synchronises [ICalTask]s and [ICalNote]s with a WebDAV server.
///
/// Each resource is stored as a single encrypted `.ics` file:
///   - Personal tasks:  `/kinetic/{username}/tasks/{uid}.ics` (personal key)
///   - Personal notes:  `/kinetic/{username}/notes/{uid}.ics` (personal key)
///   - Shared notes:    `/kinetic/shared/notes/{uid}.ics`     (family key)
///
/// All `.ics` files are AES-256-GCM encrypted; the raw bytes stored on the
/// server are `[nonce][ciphertext+mac]` (see [KineticEncryption]).
///
/// Conflict resolution: Last-Write-Wins on [ICalTask.updatedAt].
class WebDavSyncService {
  final WebDavClient client;
  final SyncConfig config;

  WebDavSyncService({required this.client, required this.config});

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  String get _tasksPath => '/kinetic/${config.username}/tasks';

  /// Pulls all tasks from the server, decrypts each one, and returns the list.
  Future<List<ICalTask>> pullTasks() async {
    final entries = await _listIcsFiles(_tasksPath);
    final tasks = <ICalTask>[];
    for (final entry in entries) {
      try {
        final blob = await client.get(entry.href);
        final plain =
            await KineticEncryption.decrypt(blob, config.personalKeyBytes);
        final ical = utf8.decode(plain);
        tasks.add(ICalSerializer.vtodoToTask(ical));
      } catch (e) {
        // Skip corrupted or unreadable files — do not abort the sync.
        continue;
      }
    }
    return tasks;
  }

  /// Encrypts [task] and PUTs it to `/kinetic/{username}/tasks/{uid}.ics`.
  Future<void> pushTask(ICalTask task) async {
    final ical = ICalSerializer.taskToVtodo(task);
    final plain = Uint8List.fromList(utf8.encode(ical));
    final blob =
        await KineticEncryption.encrypt(plain, config.personalKeyBytes);
    await client.put('$_tasksPath/${task.uid}.ics', blob);
  }

  /// Deletes the task file for [uid] from the server.
  Future<void> deleteTask(String uid) => client.delete('$_tasksPath/$uid.ics');

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  String get _personalNotesPath => '/kinetic/${config.username}/notes';
  String get _sharedNotesPath => '/kinetic/shared/notes';

  /// Pulls all personal notes (personal key) and shared notes (family key).
  Future<List<ICalNote>> pullNotes() async {
    final notes = <ICalNote>[];
    // Personal notes
    final personalEntries = await _listIcsFiles(_personalNotesPath);
    for (final entry in personalEntries) {
      try {
        final blob = await client.get(entry.href);
        final plain =
            await KineticEncryption.decrypt(blob, config.personalKeyBytes);
        notes.add(ICalSerializer.vjournalToNote(utf8.decode(plain)));
      } catch (e) {
        continue;
      }
    }
    // Shared notes — only if family key is available.
    final familyKey = config.familyKeyBytes;
    if (familyKey != null) {
      final sharedEntries = await _listIcsFiles(_sharedNotesPath);
      for (final entry in sharedEntries) {
        try {
          final blob = await client.get(entry.href);
          final plain = await KineticEncryption.decrypt(blob, familyKey);
          notes.add(ICalSerializer.vjournalToNote(utf8.decode(plain)));
        } catch (e) {
          continue;
        }
      }
    }
    return notes;
  }

  /// Encrypts [note] and pushes it to the correct folder.
  Future<void> pushNote(ICalNote note) async {
    final ical = ICalSerializer.noteToVjournal(note);
    final plain = Uint8List.fromList(utf8.encode(ical));

    if (note.isShared) {
      final familyKey = config.familyKeyBytes;
      if (familyKey == null)
        throw StateError('Family key required to push shared note');
      final blob = await KineticEncryption.encrypt(plain, familyKey);
      await client.put('$_sharedNotesPath/${note.uid}.ics', blob);
    } else {
      final blob =
          await KineticEncryption.encrypt(plain, config.personalKeyBytes);
      await client.put('$_personalNotesPath/${note.uid}.ics', blob);
    }
  }

  /// Deletes a note from the server.  [isShared] determines the folder.
  Future<void> deleteNote(String uid, {required bool isShared}) {
    final path = isShared
        ? '$_sharedNotesPath/$uid.ics'
        : '$_personalNotesPath/$uid.ics';
    return client.delete(path);
  }

  // ---------------------------------------------------------------------------
  // LWW merge helper
  // ---------------------------------------------------------------------------

  /// Merges [remote] tasks into [local] using Last-Write-Wins on [ICalTask.updatedAt].
  ///
  /// Returns:
  ///   - [merged]: the canonical list after merge (to write to the local DB)
  ///   - [toPush]: tasks from [local] that are newer than their remote counterpart
  ///     (caller should push these after calling this method)
  static ({List<ICalTask> merged, List<ICalTask> toPush}) mergeTasks(
    List<ICalTask> local,
    List<ICalTask> remote,
  ) {
    final remoteByUid = {for (final t in remote) t.uid: t};
    final localByUid = {for (final t in local) t.uid: t};

    final merged = <ICalTask>[];
    final toPush = <ICalTask>[];

    // Remote wins if updated > local, otherwise local wins (and needs push).
    for (final uid in {...remoteByUid.keys, ...localByUid.keys}) {
      final r = remoteByUid[uid];
      final l = localByUid[uid];
      if (r == null) {
        // Local-only: push to server.
        merged.add(l!);
        toPush.add(l);
      } else if (l == null) {
        // Remote-only: adopt.
        merged.add(r);
      } else if (!r.updatedAt.isBefore(l.updatedAt)) {
        // Remote is same age or newer: adopt remote.
        merged.add(r);
      } else {
        // Local is newer: keep local, push it.
        merged.add(l);
        toPush.add(l);
      }
    }
    return (merged: merged, toPush: toPush);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns PROPFIND entries whose href ends with `.ics`.
  Future<List<WebDavEntry>> _listIcsFiles(String path) async {
    try {
      final entries = await client.propfind(path);
      return entries.where((e) => e.href.endsWith('.ics')).toList();
    } on WebDavException catch (e) {
      // If the directory does not exist yet return empty list.
      if (e.message.contains('404')) return [];
      rethrow;
    }
  }
}
