import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'webdav_url.dart';

/// Lightweight WebDAV HTTP client.
///
/// All methods use HTTP Basic auth with [username] + [password].
/// The [baseUrl] must be HTTPS and should not include a trailing slash.
class WebDavClient {
  final String baseUrl;
  final String username;
  final String password;

  /// Optional [http.Client] injection for testing.
  final http.Client _http;

  WebDavClient({
    required String baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
  })  : baseUrl = WebDavUrl.requireHttps(baseUrl),
        _http = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> get _authHeaders {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $credentials'};
  }

  String _url(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final rel = path.startsWith('/') ? path.substring(1) : path;
    return '$base$rel';
  }

  // ---------------------------------------------------------------------------
  // PROPFIND — list a collection
  // ---------------------------------------------------------------------------

  /// Returns paths of all direct children of [collectionPath].
  /// Throws [WebDavException] on non-207 responses.
  Future<List<WebDavEntry>> propfind(String collectionPath) async {
    // WebDAV collections require trailing slashes to avoid 301 redirects.
    final path =
        collectionPath.endsWith('/') ? collectionPath : '$collectionPath/';
    final response = await _http.send(
      http.Request('PROPFIND', Uri.parse(_url(path)))
        ..headers.addAll(
            {..._authHeaders, 'Depth': '1', 'Content-Type': 'application/xml'})
        ..body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
            '<d:prop><d:getlastmodified/><d:getetag/>'
            '<d:resourcetype/></d:prop></d:propfind>',
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) {
      throw WebDavException(
        'PROPFIND $collectionPath → ${response.statusCode}',
        body,
        response.statusCode,
      );
    }
    return _parsePropfind(body);
  }

  // ---------------------------------------------------------------------------
  // GET — download a resource
  // ---------------------------------------------------------------------------

  /// Downloads the resource at [path] and returns its raw bytes.
  Future<Uint8List> get(String path) async {
    final response = await _http.get(
      Uri.parse(_url(path)),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw WebDavException(
        'GET $path → ${response.statusCode}',
        response.body,
        response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  // ---------------------------------------------------------------------------
  // PUT — upload a resource
  // ---------------------------------------------------------------------------

  /// Uploads [bytes] to [path].
  ///
  /// Pass [etag] to do a conditional PUT (If-Match).  Leave null for
  /// unconditional PUT (creates or overwrites).
  Future<void> put(String path, Uint8List bytes, {String? etag}) async {
    final headers = <String, String>{..._authHeaders};
    if (etag != null) headers['If-Match'] = etag;

    final response = await _http.put(
      Uri.parse(_url(path)),
      headers: headers,
      body: bytes,
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw WebDavException(
        'PUT $path → ${response.statusCode}',
        response.body,
        response.statusCode,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE — remove a resource
  // ---------------------------------------------------------------------------

  /// Deletes the resource at [path].  Succeeds silently if it does not exist
  /// (404 is treated as success).
  Future<void> delete(String path) async {
    final response = await _http.delete(
      Uri.parse(_url(path)),
      headers: _authHeaders,
    );
    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 404) {
      throw WebDavException(
        'DELETE $path → ${response.statusCode}',
        response.body,
        response.statusCode,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MKCOL — create a collection
  // ---------------------------------------------------------------------------

  /// Creates the collection at [path].  Succeeds silently if it already exists
  /// (405 Method Not Allowed on Nextcloud/Apache, 409 Conflict on some servers).
  Future<void> mkcol(String path) async {
    // WebDAV collections require trailing slashes
    final pathWithSlash = path.endsWith('/') ? path : '$path/';
    final response = await _http.send(
      http.Request('MKCOL', Uri.parse(_url(pathWithSlash)))
        ..headers.addAll(_authHeaders),
    );
    final statusCode = response.statusCode;
    if (statusCode != 201 && statusCode != 405 && statusCode != 409) {
      final body = await response.stream.bytesToString();
      throw WebDavException('MKCOL $path → $statusCode', body, statusCode);
    }
  }

  // ---------------------------------------------------------------------------
  // OPTIONS — check if WebDAV is supported
  // ---------------------------------------------------------------------------

  /// Returns true if the server responds with DAV support headers.
  Future<bool> supportsWebDav() async {
    try {
      final response = await _http.send(
        http.Request('OPTIONS', Uri.parse(_url('/')))
          ..headers.addAll(_authHeaders),
      );
      await response.stream.drain<void>();
      return response.headers.containsKey('dav') ||
          response.headers['allow']?.contains('PROPFIND') == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _http.close();

  // ---------------------------------------------------------------------------
  // PROPFIND XML parser — intentionally minimal, no xml package dependency.
  // ---------------------------------------------------------------------------

  static final _hrefRegex = RegExp(r'<[Dd](?:av)?:href>(.*?)</', dotAll: true);
  static final _etagRegex =
      RegExp(r'<[Dd](?:av)?:getetag>(.*?)</', dotAll: true);
  static final _collectionRegex = RegExp(r'<[Dd](?:av)?:collection\s*/?>');

  static List<WebDavEntry> _parsePropfind(String xml) {
    final entries = <WebDavEntry>[];
    final hrefMatches = _hrefRegex.allMatches(xml).toList();
    for (final hrefMatch in hrefMatches) {
      final href = _unescapeXml(hrefMatch.group(1)!.trim());
      // Find the surrounding <response> block to pick out etag + resourcetype.
      final blockStart = xml.lastIndexOf('<', hrefMatch.start);
      var blockEnd = xml.indexOf('</d:response>', hrefMatch.end);
      if (blockEnd == -1)
        blockEnd = xml.indexOf('</D:response>', hrefMatch.end);
      if (blockEnd == -1) continue;
      final block = xml.substring(blockStart, blockEnd);
      final etagMatch = _etagRegex.firstMatch(block);
      final etag = etagMatch != null
          ? etagMatch.group(1)!.trim().replaceAll('"', '')
          : null;
      final isCollection = _collectionRegex.hasMatch(block);
      entries
          .add(WebDavEntry(href: href, etag: etag, isCollection: isCollection));
    }
    return entries;
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

/// A single entry returned by PROPFIND.
class WebDavEntry {
  final String href;
  final String? etag;
  final bool isCollection;

  const WebDavEntry({
    required this.href,
    required this.etag,
    required this.isCollection,
  });

  @override
  String toString() =>
      'WebDavEntry(href: $href, etag: $etag, isCollection: $isCollection)';
}

/// Thrown when a WebDAV operation returns an unexpected HTTP status code.
class WebDavException implements Exception {
  final String message;
  final String? body;
  final int? statusCode;
  const WebDavException(this.message, [this.body, this.statusCode]);

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => body != null
      ? 'WebDavException: $message\n$body'
      : 'WebDavException: $message';
}
