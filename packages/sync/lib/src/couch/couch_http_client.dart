import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when CouchDB returns a non-2xx status code.
class CouchHttpException implements Exception {
  final int statusCode;
  final String reason;
  final String? docId;

  const CouchHttpException(this.statusCode, this.reason, {this.docId});

  @override
  String toString() {
    final id = docId != null ? ' (doc: $docId)' : '';
    return 'CouchHttpException($statusCode)$id: $reason';
  }
}

/// Documents returned by CouchDB's `_changes` feed, together with the
/// sequence cursor needed to resume the feed later.
class ChangesResult {
  final List<Map<String, dynamic>> docs;
  final String lastSeq;

  const ChangesResult({required this.docs, required this.lastSeq});
}

/// Thin HTTP wrapper around the CouchDB REST API.
///
/// All network-touching methods are async and throw [CouchHttpException] on
/// non-2xx responses.  Inject a custom [http.Client] for testing.
///
/// **Endpoints used:**
/// - `GET /`                    — connectivity probe (`ping`)
/// - `GET  /{db}`               — database info
/// - `PUT  /{db}`               — create database
/// - `GET  /{db}/_changes`      — incremental pull (changes feed)
/// - `POST /{db}/_bulk_docs`    — batch push
class CouchHttpClient {
  final http.Client _httpClient;
  final Uri _base;
  final String? _username;
  final String? _password;

  CouchHttpClient({
    required String host,
    required int port,
    String? username,
    String? password,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _base = Uri(scheme: 'http', host: host, port: port),
       _username = username,
       _password = password;

  /// Authorization + content-type headers, consistent on every request.
  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_username != null && _password != null) {
      final creds = base64Encode(utf8.encode('$_username:$_password'));
      h['Authorization'] = 'Basic $creds';
    }
    return h;
  }

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  /// Returns `true` if CouchDB responds with a 200 welcome document.
  Future<bool> ping() async {
    try {
      final resp = await _httpClient.get(_base, headers: _headers);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Database management
  // ---------------------------------------------------------------------------

  /// Creates [db] if it does not already exist.
  /// Safe to call on every startup — skips creation when DB already exists.
  Future<void> ensureDatabase(String db) async {
    final uri = _base.replace(path: '/$db');
    final getResp = await _httpClient.get(uri, headers: _headers);
    if (getResp.statusCode == 404) {
      final putResp = await _httpClient.put(uri, headers: _headers);
      if (putResp.statusCode != 201 && putResp.statusCode != 202) {
        throw CouchHttpException(putResp.statusCode, putResp.body);
      }
    } else if (getResp.statusCode != 200) {
      throw CouchHttpException(getResp.statusCode, getResp.body);
    }
  }

  // ---------------------------------------------------------------------------
  // Replication primitives
  // ---------------------------------------------------------------------------

  /// Fetches up to [limit] document revisions changed since sequence [since].
  ///
  /// Pass `since: '0'` to retrieve the full database.
  /// The returned [ChangesResult.lastSeq] should be persisted and used as
  /// [since] on the next call to avoid re-downloading seen documents.
  Future<ChangesResult> getChanges(
    String db, {
    required String since,
    int limit = 500,
  }) async {
    final uri = _base.replace(
      path: '/$db/_changes',
      queryParameters: {
        'since': since,
        'include_docs': 'true',
        'limit': '$limit',
        'feed': 'normal',
      },
    );
    final resp = await _httpClient.get(uri, headers: _headers);
    _assertOk(resp);

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (body['results'] as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['doc'] != null)
        .map((row) => row['doc'] as Map<String, dynamic>)
        .toList();

    return ChangesResult(docs: docs, lastSeq: '${body['last_seq']}');
  }

  /// Pushes [docs] to [db] in a single batch.
  ///
  /// Each element must contain at least `_id`.  Include `_rev` to update an
  /// existing document.  Returns the per-document result list from CouchDB.
  Future<List<Map<String, dynamic>>> bulkDocs(
    String db,
    List<Map<String, dynamic>> docs,
  ) async {
    if (docs.isEmpty) return const [];

    final uri = _base.replace(path: '/$db/_bulk_docs');
    final body = jsonEncode({'docs': docs});
    final resp = await _httpClient.post(uri, headers: _headers, body: body);
    _assertOk(resp);

    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Closes the underlying [http.Client].  Call when the sync session ends.
  void close() => _httpClient.close();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _assertOk(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CouchHttpException(resp.statusCode, resp.body);
    }
  }
}
