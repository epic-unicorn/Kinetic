import '../crypto/document_codec.dart';
import '../discovery/sync_peer.dart';
import 'couch_http_client.dart';

/// Per-document push/pull outcome from a single sync cycle.
class SyncResult {
  final SyncPeer peer;
  final int pushed;
  final int pulled;
  final List<String> errors;

  const SyncResult({
    required this.peer,
    required this.pushed,
    required this.pulled,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isClean => !hasErrors;

  @override
  String toString() =>
      'SyncResult(${peer.deviceId}: pushed=$pushed pulled=$pulled '
      'errors=${errors.length})';
}

/// Manages push-then-pull replication between a local document store and a
/// remote CouchDB peer discovered via mDNS.
///
/// **Merge strategy (Phase 2)**
/// - `FamilyPlan` conflicts: higher `crdtVersion` wins.
/// - `Task` conflicts: later `updatedAt` wins (last-write-wins).
/// - Full three-way CRDT merging will be added in a later phase.
///
/// **Scope**
/// The local store is an in-memory [Map] keyed by `_id`.  In Phase 5 this
/// will be replaced by a persistent local CouchDB replica inside the Docker
/// container or a SQLite store on mobile.
class CouchSyncService {
  static const _dbName = 'kinetic_family';

  final DocumentCodec _codec;

  /// In-memory local document store: document `_id` → latest document map.
  final Map<String, Map<String, dynamic>> _local;

  /// Tracks the last CouchDB `last_seq` value per peer device-id.
  /// This cursor allows incremental pulls (only changed docs since last sync).
  final Map<String, String> _seqByPeer = {};

  CouchSyncService({
    DocumentCodec? codec,
    Map<String, Map<String, dynamic>>? seedDocs,
  }) : _codec = codec ?? DocumentCodec(),
       _local = seedDocs != null ? Map.of(seedDocs) : {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Inserts or updates [doc] in the local store.
  /// [doc] must contain a non-null `_id` field.
  void upsertLocal(Map<String, dynamic> doc) {
    final id = doc['_id'] as String?;
    assert(id != null, 'upsertLocal: doc must have a _id field');
    if (id != null) _local[id] = doc;
  }

  /// Read-only snapshot of all locally held documents.
  List<Map<String, dynamic>> get localDocs =>
      List<Map<String, dynamic>>.unmodifiable(_local.values.toList());

  /// Performs one push-then-pull cycle with [peer].
  ///
  /// 1. **Push** — encrypts all local docs and sends them via `_bulk_docs`.
  /// 2. **Pull** — fetches docs changed since the stored cursor, decrypts,
  ///    and merges into the local store using the `crdtVersion` / LWW rule.
  ///
  /// Returns a [SyncResult] summarising what was transferred.
  Future<SyncResult> syncWithPeer({
    required SyncPeer peer,
    required CouchHttpClient client,
    required List<int> meshKey,
  }) async {
    await client.ensureDatabase(_dbName);

    final errors = <String>[];
    var pushed = 0;
    var pulled = 0;

    // -------------------------------------------------------------------------
    // PUSH — send all locally known docs to the peer.
    // In a future optimisation we'd track a local dirty-set and only push
    // changed documents.  For now, all docs are pushed every cycle.
    // -------------------------------------------------------------------------
    try {
      final encrypted = await Future.wait(
        _local.values.map((d) => _codec.encrypt(d, meshKey)),
      );
      final results = await client.bulkDocs(_dbName, encrypted);
      pushed = results.where((r) => r['ok'] == true).length;
      for (final r in results.where((r) => r['error'] != null)) {
        errors.add(
          'push conflict on ${r['id']}: ${r['error']} (${r['reason']})',
        );
      }
    } catch (e) {
      errors.add('push batch failed: $e');
    }

    // -------------------------------------------------------------------------
    // PULL — fetch only documents the peer has that we haven't seen yet.
    // -------------------------------------------------------------------------
    try {
      final since = _seqByPeer[peer.deviceId] ?? '0';
      final changes = await client.getChanges(_dbName, since: since);

      for (final encDoc in changes.docs) {
        try {
          final plain = await _codec.decrypt(encDoc, meshKey);
          final id = plain['_id'] as String?;
          if (id == null) continue;
          _local[id] = _merge(_local[id], plain);
          pulled++;
        } catch (e) {
          errors.add('decrypt failed for a pulled doc: $e');
        }
      }
      _seqByPeer[peer.deviceId] = changes.lastSeq;
    } catch (e) {
      errors.add('pull failed: $e');
    }

    return SyncResult(
      peer: peer,
      pushed: pushed,
      pulled: pulled,
      errors: errors,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Merges an [incoming] remote document with the [existing] local copy.
  ///
  /// Decision order:
  /// 1. If [existing] is null → accept incoming unconditionally.
  /// 2. Higher `crdtVersion` → that document wins.
  /// 3. Tiebreak: later `updatedAt` ISO-8601 timestamp wins.
  /// 4. Fallback: keep [existing] (local-wins safety net).
  Map<String, dynamic> _merge(
    Map<String, dynamic>? existing,
    Map<String, dynamic> incoming,
  ) {
    if (existing == null) return incoming;

    final evLocal = (existing['crdtVersion'] as num?)?.toInt() ?? 0;
    final evRemote = (incoming['crdtVersion'] as num?)?.toInt() ?? 0;

    if (evRemote > evLocal) return incoming;
    if (evRemote < evLocal) return existing;

    // Same crdtVersion — fall back to updatedAt (Task LWW).
    final tsLocal = DateTime.tryParse(existing['updatedAt'] as String? ?? '');
    final tsRemote = DateTime.tryParse(incoming['updatedAt'] as String? ?? '');

    if (tsLocal != null && tsRemote != null && tsRemote.isAfter(tsLocal)) {
      return incoming;
    }

    return existing;
  }
}
