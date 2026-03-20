/// Minimal persistence interface used by [ApprovalService] and [TicketService].
///
/// Production wiring: an adapter that forwards to [CouchSyncService.upsertLocal]
/// and [CouchSyncService.localDocs] (see `apps/parent/lib/support/`).
/// Test wiring: [InMemoryDocumentStore].
abstract class DocumentStore {
  /// Persist or overwrite [doc], identified by its `_id` field.
  ///
  /// [doc] MUST contain an `_id` key; calling code is responsible for setting it.
  void upsert(Map<String, dynamic> doc);

  /// All documents currently in the store.
  List<Map<String, dynamic>> get all;
}
