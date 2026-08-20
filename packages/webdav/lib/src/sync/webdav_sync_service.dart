import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../encryption/kinetic_encryption.dart';
import '../ical/ical_note.dart';
import '../ical/ical_serializer.dart';
import '../ical/ical_task.dart';
import '../presence_info.dart';
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
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
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

  /// Extracts the path-relative-to-baseUrl from a PROPFIND href.
  /// PROPFIND responses include full paths like `/webdav/kinetic/shared/notes/file.ics`,
  /// but client.get() needs just the kinetic-relative path like `/kinetic/shared/notes/file.ics`.
  String _relativizeHref(String href) {
    // Extract the path component from baseUrl.
    final Uri baseUri = Uri.parse(client.baseUrl);
    final basePath = baseUri.path;
    // If href starts with basePath, remove it.
    if (basePath.isNotEmpty && href.startsWith(basePath)) {
      return href.substring(basePath.length);
    }
    return href;
  }

  /// Pulls all personal notes (personal key) and shared notes (family key).
  Future<List<ICalNote>> pullNotes() async {
    final notes = <ICalNote>[];
    // Personal notes
    final personalEntries = await _listIcsFiles(_personalNotesPath);
    if (kDebugMode) {
      debugPrint('Found ${personalEntries.length} personal note files');
    }
    for (final entry in personalEntries) {
      try {
        final href = _relativizeHref(entry.href);
        if (kDebugMode) debugPrint('Attempting to GET personal note: $href');
        final blob = await client.get(href);
        final plain =
            await KineticEncryption.decrypt(blob, config.personalKeyBytes);
        notes.add(ICalSerializer.vjournalToNote(utf8.decode(plain)));
      } on WebDavException catch (e) {
        // Skip 404s — file may have been deleted or PROPFIND returned stale entry
        if (e.message.contains('404')) {
          if (kDebugMode) {
            debugPrint(
              'Personal note file not found (may be stale): ${entry.href}',
            );
          }
          continue;
        }
        if (kDebugMode) {
          debugPrint('Error decrypting personal note from ${entry.href}: $e');
        }
        continue;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error decrypting personal note from ${entry.href}: $e');
        }
        continue;
      }
    }
    // Shared notes — only if family key is available.
    final familyKey = config.familyKeyBytes;
    if (familyKey != null) {
      final sharedEntries = await _listIcsFiles(_sharedNotesPath);
      if (kDebugMode) {
        debugPrint('Found ${sharedEntries.length} shared note files');
      }
      for (final entry in sharedEntries) {
        try {
          final href = _relativizeHref(entry.href);
          if (kDebugMode) debugPrint('Attempting to GET shared note: $href');
          final blob = await client.get(href);
          final plain = await KineticEncryption.decrypt(blob, familyKey);
          notes.add(ICalSerializer.vjournalToNote(utf8.decode(plain)));
        } on WebDavException catch (e) {
          // Skip 404s — file may have been deleted or PROPFIND returned stale entry
          if (e.message.contains('404')) {
            if (kDebugMode) {
              debugPrint(
                'Shared note file not found (may be stale): ${entry.href}',
              );
            }
            continue;
          }
          if (kDebugMode) {
            debugPrint('Error decrypting shared note from ${entry.href}: $e');
          }
          continue;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error decrypting shared note from ${entry.href}: $e');
          }
          continue;
        }
      }
    } else {
      if (kDebugMode) debugPrint('No family key available, skipping shared notes');
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

  // ---------------------------------------------------------------------------
  // Shared Tasks (parent→kids assignments)
  // ---------------------------------------------------------------------------

  String get _sharedTasksPath => '/kinetic/shared/tasks';

  /// Pulls all shared tasks from `/kinetic/shared/tasks/` (family key encrypted).
  /// Used by the kids app to receive parent-assigned tasks.
  Future<List<ICalTask>> pullSharedTasks() async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return [];
    final entries = await _listIcsFiles(_sharedTasksPath);
    final tasks = <ICalTask>[];
    for (final entry in entries) {
      try {
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
        final plain = await KineticEncryption.decrypt(blob, familyKey);
        tasks.add(ICalSerializer.vtodoToTask(utf8.decode(plain)));
      } catch (e) {
        continue;
      }
    }
    return tasks;
  }

  /// Encrypts [task] with the family key and PUTs it to `/kinetic/shared/tasks/{uid}.ics`.
  Future<void> pushSharedTask(ICalTask task) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null)
      throw StateError('Family key required to push shared tasks');
    final ical = ICalSerializer.taskToVtodo(task);
    final plain = Uint8List.fromList(utf8.encode(ical));
    final blob = await KineticEncryption.encrypt(plain, familyKey);
    await client.put('$_sharedTasksPath/${task.uid}.ics', blob);
  }

  /// Deletes a shared task from `/kinetic/shared/tasks/{uid}.ics`.
  Future<void> deleteSharedTask(String uid) =>
      client.delete('$_sharedTasksPath/$uid.ics');

  // ---------------------------------------------------------------------------
  // Proposals (JSON-based)
  // ---------------------------------------------------------------------------

  String get _proposalsPath => '/kinetic/shared/proposals';

  /// Pulls all proposals from the shared folder (encrypted with family key).
  /// Returns a list of JSON-decoded proposal maps.
  Future<List<Map<String, dynamic>>> pullProposals() async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return []; // No family key, no proposals to pull

    final entries = await _listJsonFiles(_proposalsPath);
    final proposals = <Map<String, dynamic>>[];

    for (final entry in entries) {
      try {
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
        final plain = await KineticEncryption.decrypt(blob, familyKey);
        final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        proposals.add(json);
      } catch (e) {
        continue; // Skip corrupted files
      }
    }
    return proposals;
  }

  /// Encrypts [proposalJson] and PUTs it to `/kinetic/shared/proposals/{id}.json`.
  /// Creates the directory on-demand if it doesn't exist (for backward compatibility
  /// with accounts set up before this feature was added).
  Future<void> pushProposal(Map<String, dynamic> proposalJson) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null)
      throw StateError('Family key required to push proposals');

    final id = proposalJson['id'] as String;
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(proposalJson)));
    final blob = await KineticEncryption.encrypt(plain, familyKey);

    await _putWithCollectionFallback('$_proposalsPath/$id.json', blob);
  }

  /// Deletes a proposal file from the server.
  Future<void> deleteProposal(String id) =>
      client.delete('$_proposalsPath/$id.json');

  // ---------------------------------------------------------------------------
  // Load Metrics (JSON-based)
  // ---------------------------------------------------------------------------

  String get _loadPath => '/kinetic/shared/load';

  /// Pulls all family members' load metrics (encrypted with family key).
  /// Returns a list of JSON-decoded load metrics maps.
  Future<List<Map<String, dynamic>>> pullLoadMetrics() async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return []; // No family key, no metrics to pull

    final entries = await _listJsonFiles(_loadPath);
    final metrics = <Map<String, dynamic>>[];

    for (final entry in entries) {
      try {
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
        final plain = await KineticEncryption.decrypt(blob, familyKey);
        final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        metrics.add(json);
      } catch (e) {
        continue;
      }
    }
    return metrics;
  }

  /// Encrypts and PUTs load metrics to `/kinetic/shared/load/{parentId}.json`.
  /// Creates the directory on-demand if it doesn't exist (for backward compatibility
  /// with accounts set up before this feature was added).
  Future<void> pushLoadMetrics(Map<String, dynamic> metricsJson) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null)
      throw StateError('Family key required to push load metrics');

    final parentId = metricsJson['parentId'] as String;
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(metricsJson)));
    final blob = await KineticEncryption.encrypt(plain, familyKey);

    await _putWithCollectionFallback('$_loadPath/$parentId.json', blob);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// HTTP status codes returned when PUT targets a file in a missing collection.
  static const _missingCollectionStatuses = ['403', '404', '409'];

  bool _isMissingCollectionError(WebDavException e) =>
      _missingCollectionStatuses.any(e.message.contains);

  /// PUTs [bytes] to [path], creating the parent collection on-demand if needed.
  Future<void> _putWithCollectionFallback(String path, Uint8List bytes) async {
    try {
      await client.put(path, bytes);
    } on WebDavException catch (e) {
      if (!_isMissingCollectionError(e)) rethrow;
      final lastSlash = path.lastIndexOf('/');
      if (lastSlash <= 0) rethrow;
      final collectionPath = path.substring(0, lastSlash);
      try {
        await client.mkcol(collectionPath);
      } catch (_) {
        // Directory may already exist, silently ignore.
      }
      await client.put(path, bytes);
    }
  }

  /// Returns PROPFIND entries whose href ends with `.json`.
  Future<List<WebDavEntry>> _listJsonFiles(String path) async {
    try {
      final entries = await client.propfind(path);
      return entries.where((e) => e.href.endsWith('.json')).toList();
    } on WebDavException catch (e) {
      if (e.message.contains('404')) return [];
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Presence heartbeat
  // ---------------------------------------------------------------------------

  String get _presencePath => '/kinetic/shared/presence';
  String get _disconnectPath => '/kinetic/shared/disconnect';

  /// Writes a presence heartbeat for [info] to the shared presence folder,
  /// encrypted with the family key.  No-op when no family key is available.
  Future<void> pushPresence(PresenceInfo info) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return;

    final plain = Uint8List.fromList(utf8.encode(jsonEncode(info.toJson())));
    final blob = await KineticEncryption.encrypt(plain, familyKey);

    await _putWithCollectionFallback(
      '$_presencePath/${info.deviceId}.json',
      blob,
    );
  }

  /// Pulls all presence entries from the shared presence folder.
  /// Returns an empty list when no family key is available or no entries exist.
  Future<List<PresenceInfo>> pullPresence() async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return [];

    final entries = await _listJsonFiles(_presencePath);
    final result = <PresenceInfo>[];
    for (final entry in entries) {
      try {
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
        final plain = await KineticEncryption.decrypt(blob, familyKey);
        final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        final presence = PresenceInfo.tryFromJson(json);
        if (presence != null) result.add(presence);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Disconnect tombstones
  // ---------------------------------------------------------------------------

  /// Writes a disconnect tombstone for [deviceId], signalling to other
  /// family members that this device has intentionally left.
  Future<void> pushDisconnect(DisconnectTombstone tombstone) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return;

    final plain =
        Uint8List.fromList(utf8.encode(jsonEncode(tombstone.toJson())));
    final blob = await KineticEncryption.encrypt(plain, familyKey);

    await _putWithCollectionFallback(
      '$_disconnectPath/${tombstone.deviceId}.json',
      blob,
    );
  }

  /// Pulls all disconnect tombstones from the shared disconnect folder.
  Future<List<DisconnectTombstone>> pullDisconnects() async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return [];

    final entries = await _listJsonFiles(_disconnectPath);
    final result = <DisconnectTombstone>[];
    for (final entry in entries) {
      try {
        final href = _relativizeHref(entry.href);
        final blob = await client.get(href);
        final plain = await KineticEncryption.decrypt(blob, familyKey);
        final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        result.add(DisconnectTombstone.fromJson(json));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// Removes the disconnect tombstone for [deviceId] from the server.
  Future<void> deleteDisconnect(String deviceId) =>
      client.delete('$_disconnectPath/$deviceId.json');

  /// Removes the presence entry for [deviceId] from the server.
  Future<void> deletePresence(String deviceId) =>
      client.delete('$_presencePath/$deviceId.json');

  // ---------------------------------------------------------------------------
  // XP Reset
  // ---------------------------------------------------------------------------

  String get _xpResetPath => '/kinetic/shared/xp-reset';

  /// Writes an XP-reset timestamp for [kidId] to the shared folder.
  /// The kids app reads this during sync and only counts XP earned after this time.
  Future<void> pushXpReset(String kidId, DateTime resetAt) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) throw StateError('Family key required to push XP reset');
    final json = jsonEncode({
      'kidId': kidId,
      'resetAt': resetAt.toUtc().toIso8601String(),
    });
    final plain = Uint8List.fromList(utf8.encode(json));
    final blob = await KineticEncryption.encrypt(plain, familyKey);
    await _putWithCollectionFallback('$_xpResetPath/$kidId.json', blob);
  }

  /// Reads the XP-reset timestamp for [kidId], or null if none has been set.
  Future<DateTime?> pullXpReset(String kidId) async {
    final familyKey = config.familyKeyBytes;
    if (familyKey == null) return null;
    try {
      final blob = await client.get('$_xpResetPath/$kidId.json');
      final plain = await KineticEncryption.decrypt(blob, familyKey);
      final data = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final resetAtStr = data['resetAt'] as String?;
      if (resetAtStr == null) return null;
      return DateTime.parse(resetAtStr);
    } catch (_) {
      return null;
    }
  }
}
