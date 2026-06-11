import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_webdav/kinetic_webdav.dart';

/// Minimal HTTP client that returns a fixed sequence of status codes.
class _SequenceHttpClient extends http.BaseClient {
  _SequenceHttpClient(this._statusCodes);

  final List<int> _statusCodes;
  int _call = 0;
  final methods = <String>[];
  final paths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    methods.add(request.method);
    paths.add(request.url.path);
    final status = _statusCodes[_call++];
    return http.StreamedResponse(
      Stream.value(Uint8List(0)),
      status,
    );
  }
}

void main() {
  group('WebDavSyncService.pushXpReset', () {
    late WebDavSyncService service;
    late _SequenceHttpClient httpClient;

    setUp(() {
      httpClient = _SequenceHttpClient([409, 201, 201]);
      final davClient = WebDavClient(
        baseUrl: 'https://dav.example.com',
        username: 'alice',
        password: 'secret',
        httpClient: httpClient,
      );
      service = WebDavSyncService(
        client: davClient,
        config: SyncConfig(
          serverUrl: 'https://dav.example.com',
          username: 'alice',
          password: 'secret',
          parentId: 'parent-1',
          personalKeyBytes: KineticEncryption.generatePersonalKey(),
          familyKeyBytes: KineticEncryption.generateFamilyKey(),
        ),
      );
    });

    test('creates collection and retries when first PUT returns 409', () async {
      await service.pushXpReset('kid-123', DateTime.utc(2026, 6, 11, 12));

      expect(httpClient.methods, ['PUT', 'MKCOL', 'PUT']);
      expect(httpClient.paths.first, '/kinetic/shared/xp-reset/kid-123.json');
      expect(httpClient.paths.last, '/kinetic/shared/xp-reset/kid-123.json');
      expect(
        httpClient.paths[1],
        '/kinetic/shared/xp-reset/',
      );
    });

    test('throws when family key is missing', () async {
      final davClient = WebDavClient(
        baseUrl: 'https://dav.example.com',
        username: 'alice',
        password: 'secret',
        httpClient: _SequenceHttpClient([201]),
      );
      final noKeyService = WebDavSyncService(
        client: davClient,
        config: SyncConfig(
          serverUrl: 'https://dav.example.com',
          username: 'alice',
          password: 'secret',
          parentId: 'parent-1',
          personalKeyBytes: KineticEncryption.generatePersonalKey(),
        ),
      );

      expect(
        () => noKeyService.pushXpReset('kid-123', DateTime.utc(2026, 6, 11)),
        throwsA(isA<StateError>()),
      );
    });
  });
}
