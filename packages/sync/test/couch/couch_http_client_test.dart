import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_sync/kinetic_sync.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_http_client.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'Content-Type': 'application/json'});

// Convenience matcher for any Uri whose path equals [p].
Matcher _uriPath(String p) => isA<Uri>().having((u) => u.path, 'path', p);

Matcher _uriQueryParam(String key, String value) =>
    isA<Uri>().having((u) => u.queryParameters[key], 'query[$key]', value);

void main() {
  late MockHttpClient mockHttp;
  late CouchHttpClient sut;

  setUpAll(registerFallbackValues);

  setUp(() {
    mockHttp = MockHttpClient();
    sut = CouchHttpClient(
      host: 'localhost',
      port: 5984,
      username: 'admin',
      password: 'secret',
      httpClient: mockHttp,
    );
  });

  group('CouchHttpClient.ping', () {
    test('returns true when CouchDB responds 200', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => _json({'couchdb': 'Welcome', 'version': '3.3.3'}));

      expect(await sut.ping(), isTrue);
    });

    test('returns false when server is unreachable', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Connection refused'));

      expect(await sut.ping(), isFalse);
    });

    test('returns false on 503 maintenance', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('unavailable', 503));

      expect(await sut.ping(), isFalse);
    });
  });

  group('CouchHttpClient.ensureDatabase', () {
    test('does nothing when DB already exists (200)', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({'db_name': 'kinetic_family'}));

      await expectLater(sut.ensureDatabase('kinetic_family'), completes);
      verifyNever(() => mockHttp.put(any(), headers: any(named: 'headers')));
    });

    test('creates DB when it returns 404', () async {
      when(() => mockHttp.get(
            any(that: _uriPath('/kinetic_family')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Not Found', 404));

      when(() => mockHttp.put(
            any(that: _uriPath('/kinetic_family')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => _json({'ok': true}, status: 201));

      await expectLater(sut.ensureDatabase('kinetic_family'), completes);
      verify(() => mockHttp.put(any(), headers: any(named: 'headers')))
          .called(1);
    });

    test('throws CouchHttpException when GET returns 500', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Internal Error', 500));

      await expectLater(
        sut.ensureDatabase('kinetic_family'),
        throwsA(isA<CouchHttpException>()),
      );
    });
  });

  group('CouchHttpClient.getChanges', () {
    final changesBody = {
      'results': [
        {
          'seq': '1-g1',
          'id': 'task:001',
          'doc': {'_id': 'task:001', 'enc': 1, 'iv': 'abc', 'ct': 'xyz'}
        },
        {
          'seq': '2-g2',
          'id': 'task:002',
          'doc': {'_id': 'task:002', 'enc': 1, 'iv': 'def', 'ct': 'uvw'}
        },
      ],
      'last_seq': '2-g2',
    };

    test('returns correct docs and lastSeq', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(changesBody));

      final result = await sut.getChanges('kinetic_family', since: '0');

      expect(result.docs, hasLength(2));
      expect(result.docs.first['_id'], equals('task:001'));
      expect(result.lastSeq, equals('2-g2'));
    });

    test('passes since parameter in query string', () async {
      when(() => mockHttp.get(
                any(that: _uriQueryParam('since', '5-seq')),
                headers: any(named: 'headers'),
              ))
          .thenAnswer((_) async => _json({'results': [], 'last_seq': '5-seq'}));

      final result = await sut.getChanges('kinetic_family', since: '5-seq');
      expect(result.docs, isEmpty);
      expect(result.lastSeq, equals('5-seq'));
    });

    test('skips result rows with null doc (deleted tombstones without doc)',
        () async {
      final body = {
        'results': [
          {'seq': '1-x', 'id': 'task:gone', 'doc': null},
          {
            'seq': '2-x',
            'id': 'task:alive',
            'doc': {'_id': 'task:alive'}
          },
        ],
        'last_seq': '2-x',
      };
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json(body));

      final result = await sut.getChanges('kinetic_family', since: '0');
      expect(result.docs, hasLength(1));
    });

    test('throws CouchHttpException on 401 Unauthorized', () async {
      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer(
              (_) async => http.Response('{"error":"unauthorized"}', 401));

      await expectLater(
        sut.getChanges('kinetic_family', since: '0'),
        throwsA(isA<CouchHttpException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('CouchHttpClient.bulkDocs', () {
    test('returns empty list for empty input without calling HTTP', () async {
      final result = await sut.bulkDocs('kinetic_family', []);
      expect(result, isEmpty);
      verifyNever(() => mockHttp.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('posts to /{db}/_bulk_docs and returns result list', () async {
      final responseBody = [
        {'id': 'task:001', 'rev': '1-abc', 'ok': true},
        {'id': 'task:002', 'rev': '1-def', 'ok': true},
      ];

      when(() => mockHttp.post(
            any(that: _uriPath('/kinetic_family/_bulk_docs')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _json(responseBody));

      final result = await sut.bulkDocs('kinetic_family', [
        {'_id': 'task:001', 'enc': 1},
        {'_id': 'task:002', 'enc': 1},
      ]);

      expect(result, hasLength(2));
      expect(result.first['ok'], isTrue);
    });

    test('includes Authorization header in request', () async {
      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json([
                {'ok': true}
              ]));

      await sut.bulkDocs('kinetic_family', [
        {'_id': 'task:x', 'enc': 1}
      ]);

      final captured = verify(() => mockHttp.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          )).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], startsWith('Basic '));
    });
  });
}
