import 'document_store.dart';

/// Simple in-memory [DocumentStore] for unit tests and quick prototyping.
class InMemoryDocumentStore implements DocumentStore {
  final Map<String, Map<String, dynamic>> _docs;

  /// Optionally pre-seed documents. The map is copied so the caller's original
  /// is not mutated.
  InMemoryDocumentStore({Map<String, Map<String, dynamic>>? seed})
    : _docs = seed != null ? Map.of(seed) : {};

  @override
  void upsert(Map<String, dynamic> doc) {
    final id = doc['_id'] as String;
    _docs[id] = Map.of(doc);
  }

  @override
  List<Map<String, dynamic>> get all =>
      List.unmodifiable(_docs.values.toList());

  /// Retrieves a document by its `_id`, or `null` if not present.
  Map<String, dynamic>? operator [](String id) =>
      _docs[id] != null ? Map.of(_docs[id]!) : null;
}
