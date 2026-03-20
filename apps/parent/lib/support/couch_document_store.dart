import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

/// Adapts [CouchSyncService] to the [DocumentStore] interface expected by
/// [ApprovalService] and [TicketService].
///
/// All reads/writes go through [CouchSyncService.localDocs] /
/// [CouchSyncService.upsertLocal] so that every mutation is automatically
/// included in the next P2P sync heartbeat.
class CouchDocumentStore implements DocumentStore {
  final CouchSyncService _sync;

  const CouchDocumentStore(this._sync);

  @override
  void upsert(Map<String, dynamic> doc) => _sync.upsertLocal(doc);

  @override
  List<Map<String, dynamic>> get all => _sync.localDocs;
}
