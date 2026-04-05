import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// SharedStorage — in-memory file store shared between multiple FakeHttpClients.
//
// Keys are normalised URL paths, e.g. '/kinetic/shared/proposals/abc.json'.
// Two [FakeHttpClient] instances sharing one [SharedStorage] behave as if
// they talk to the same WebDAV server.
// ---------------------------------------------------------------------------

class SharedStorage {
  final _files = <String, Uint8List>{};

  void put(String path, Uint8List bytes) => _files[_normalize(path)] = bytes;

  Uint8List? get(String path) => _files[_normalize(path)];

  bool remove(String path) => _files.remove(_normalize(path)) != null;

  /// Returns paths of all direct children of [parentPath].
  /// A "child" is a stored key of the form "<parentPath>/<name>" with no
  /// further slashes in <name>.
  Iterable<String> listChildren(String parentPath) {
    final prefix = '${_normalize(parentPath)}/';
    return _files.keys.where((k) {
      if (!k.startsWith(prefix)) return false;
      final rest = k.substring(prefix.length);
      return rest.isNotEmpty && !rest.contains('/');
    });
  }

  static String _normalize(String path) {
    var p = path.startsWith('/') ? path : '/$path';
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}

// ---------------------------------------------------------------------------
// FakeHttpClient — implements http.BaseClient against SharedStorage.
//
// Handles the four WebDAV verbs used by WebDavClient:
//   GET, PUT, DELETE, PROPFIND (and MKCOL as a no-op).
// ---------------------------------------------------------------------------

class FakeHttpClient extends http.BaseClient {
  final SharedStorage storage;

  FakeHttpClient(this.storage);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path; // e.g. '/kinetic/shared/proposals/abc.json'
    final method = request.method.toUpperCase();

    // Read body bytes — needed for PUT and PROPFIND (XML body).
    // Use direct bodyBytes access for http.Request, stream otherwise.
    Uint8List bodyBytes;
    if (request is http.Request) {
      bodyBytes = request.bodyBytes;
    } else {
      final collected = await request.finalize().toBytes();
      bodyBytes = collected is Uint8List ? collected : Uint8List.fromList(collected);
    }

    switch (method) {
      // ── GET ──────────────────────────────────────────────────────────────
      case 'GET':
        final bytes = storage.get(path);
        if (bytes == null) return _rawResponse(404, Uint8List(0));
        return _rawResponse(200, bytes);

      // ── PUT ───────────────────────────────────────────────────────────────
      case 'PUT':
        storage.put(path, bodyBytes);
        return _rawResponse(201, Uint8List(0));

      // ── DELETE ────────────────────────────────────────────────────────────
      case 'DELETE':
        storage.remove(path);
        return _rawResponse(204, Uint8List(0));

      // ── MKCOL ─────────────────────────────────────────────────────────────
      case 'MKCOL':
        return _rawResponse(201, Uint8List(0));

      // ── PROPFIND ──────────────────────────────────────────────────────────
      case 'PROPFIND':
        final children = storage.listChildren(path).toList();
        final xmlBytes = Uint8List.fromList(
          utf8.encode(_buildPropfindXml(path, children)),
        );
        return _rawResponse(207, xmlBytes);

      // ── OPTIONS ───────────────────────────────────────────────────────────
      case 'OPTIONS':
        return _rawResponse(200, Uint8List(0), headers: {
          'dav': '1, 2',
          'allow': 'OPTIONS, GET, PUT, DELETE, PROPFIND, MKCOL',
        });

      default:
        return _rawResponse(405, Uint8List(0));
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static http.StreamedResponse _rawResponse(
    int statusCode,
    Uint8List bytes, {
    Map<String, String>? headers,
  }) {
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      statusCode,
      contentLength: bytes.length,
      headers: headers ?? const {},
    );
  }

  /// Generates a minimal WebDAV multi-status XML response.
  ///
  /// The collection entry is included so [WebDavClient._parsePropfind] always
  /// finds at least one response block, then filters by `.ics`/`.json` suffix.
  static String _buildPropfindXml(
    String collectionPath,
    List<String> childPaths,
  ) {
    // Ensure collection href ends with slash (conventional WebDAV).
    final collHref = collectionPath.endsWith('/')
        ? collectionPath
        : '$collectionPath/';

    final sb = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<d:multistatus xmlns:d="DAV:">');

    // Collection itself.
    sb
      ..writeln('  <d:response>')
      ..writeln('    <d:href>$collHref</d:href>')
      ..writeln('    <d:propstat><d:prop>')
      ..writeln('      <d:resourcetype><d:collection/></d:resourcetype>')
      ..writeln('    </d:prop></d:propstat>')
      ..writeln('  </d:response>');

    for (final child in childPaths) {
      sb
        ..writeln('  <d:response>')
        ..writeln('    <d:href>$child</d:href>')
        ..writeln('    <d:propstat><d:prop>')
        ..writeln('      <d:getetag>"etag-${child.hashCode}"</d:getetag>')
        ..writeln('    </d:prop></d:propstat>')
        ..writeln('  </d:response>');
    }

    sb.writeln('</d:multistatus>');
    return sb.toString();
  }
}

