import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_sync/kinetic_sync.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_http_client.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _peer = SyncPeer(
  deviceId: 'hub-001',
  host: 'homeserver.local',
  port: 5984,
  type: PeerType.hub,
);

final _meshKey = List<int>.generate(32, (i) => i + 1);

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'Content-Type': 'application/json'});

void main() {
  setUpAll(registerFallbackValues);

  group('CouchSyncService', () {
    late MockHttpClient mockHttp;
    late CouchHttpClient couchClient;

    setUp(() {
      mockHttp = MockHttpClient();
      couchClient = CouchHttpClient(
        host: _peer.host,
        port: _peer.port,
        httpClient: mockHttp,
      );

      // Stub ensureDatabase → GET 200 (db exists)
      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => _json({'db_name': 'kinetic_family'}));
    });

    // -------------------------------------------------------------------------
    // Push
    // -------------------------------------------------------------------------

    test('pushes all local docs to peer on sync', () async {
      final sut = CouchSyncService(seedDocs: {
        'task:001': {
          '_id': 'task:001',
          'title': 'Clean Room',
          'xpReward': 50,
        },
      });

      // Stub changes feed → empty (no new remote docs)
      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family/_changes')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => _json({'results': [], 'last_seq': '1-x'}));

      // Stub bulk_docs → 1 ok
      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json([
                {'id': 'task:001', 'rev': '1-a', 'ok': true}
              ]));

      final result = await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      expect(result.pushed, equals(1));
      expect(result.pulled, equals(0));
      expect(result.isClean, isTrue);
    });

    // -------------------------------------------------------------------------
    // Pull
    // -------------------------------------------------------------------------

    test('decrypts and merges pulled docs into local store', () async {
      final sut = CouchSyncService();
      final codec = DocumentCodec();

      // A remote doc that doesn't exist locally.
      final remoteDoc = {
        '_id': 'task:remote',
        'title': 'Remote Task',
        'xpReward': 20
      };
      final encRemote = await codec.encrypt(remoteDoc, _meshKey);

      // No local docs → push body is empty → stub accordingly
      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json(<dynamic>[]));

      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family/_changes')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => _json({
            'results': [
              {'seq': '1-r', 'id': 'task:remote', 'doc': encRemote}
            ],
            'last_seq': '1-r',
          }));

      final result = await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      expect(result.pulled, equals(1));

      final local = sut.localDocs;
      expect(local.any((d) => d['_id'] == 'task:remote'), isTrue);
      final pulled = local.firstWhere((d) => d['_id'] == 'task:remote');
      expect(pulled['title'], equals('Remote Task'));
    });

    // -------------------------------------------------------------------------
    // CRDT merge behaviour
    // -------------------------------------------------------------------------

    test('higher crdtVersion remote doc overwrites lower local copy', () async {
      final sut = CouchSyncService(seedDocs: {
        'plan:main': {
          '_id': 'plan:main',
          'name': 'Old Name',
          'crdtVersion': 2,
        },
      });
      final codec = DocumentCodec();

      final remoteDoc = {
        '_id': 'plan:main',
        'name': 'New Name',
        'crdtVersion': 5, // higher → wins
      };
      final encRemote = await codec.encrypt(remoteDoc, _meshKey);

      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json([
                {'id': 'plan:main', 'ok': true}
              ]));

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({
                'results': [
                  {'seq': '3-x', 'id': 'plan:main', 'doc': encRemote}
                ],
                'last_seq': '3-x',
              }));

      await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      final local = sut.localDocs.firstWhere((d) => d['_id'] == 'plan:main');
      expect(local['name'], equals('New Name'));
      expect(local['crdtVersion'], equals(5));
    });

    test('lower crdtVersion remote doc is discarded (local wins)', () async {
      final sut = CouchSyncService(seedDocs: {
        'plan:main': {
          '_id': 'plan:main',
          'name': 'Correct Name',
          'crdtVersion': 10, // local is newer
        },
      });
      final codec = DocumentCodec();

      final remoteDoc = {
        '_id': 'plan:main',
        'name': 'Stale Remote',
        'crdtVersion': 3,
      };
      final encRemote = await codec.encrypt(remoteDoc, _meshKey);

      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json([
                {'id': 'plan:main', 'ok': true}
              ]));

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json({
                'results': [
                  {'seq': '1-y', 'id': 'plan:main', 'doc': encRemote}
                ],
                'last_seq': '1-y',
              }));

      await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      final local = sut.localDocs.firstWhere((d) => d['_id'] == 'plan:main');
      expect(local['name'], equals('Correct Name'));
      expect(local['crdtVersion'], equals(10));
    });

    // -------------------------------------------------------------------------
    // Sequence cursor
    // -------------------------------------------------------------------------

    test('second sync uses lastSeq from first pull as since cursor', () async {
      final sut = CouchSyncService();

      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _json(<dynamic>[]));

      // First sync returns last_seq = '5-abc'
      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family/_changes')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        return _json({'results': [], 'last_seq': '5-abc'});
      });

      await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      // Second sync — capture the actual Uri to check the `since` parameter.
      Uri? capturedUri;
      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family/_changes')),
            headers: any(named: 'headers'),
          )).thenAnswer((invocation) async {
        capturedUri = invocation.positionalArguments.first as Uri;
        return _json({'results': [], 'last_seq': '5-abc'});
      });

      await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      expect(capturedUri?.queryParameters['since'], equals('5-abc'));
    });

    // -------------------------------------------------------------------------
    // Error resilience
    // -------------------------------------------------------------------------

    test('push error is recorded in SyncResult but pull still runs', () async {
      final sut = CouchSyncService(seedDocs: {
        'task:x': {'_id': 'task:x', 'title': 'Fail Push'},
      });

      when(() => mockHttp.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenThrow(Exception('Network error'));

      when(() => mockHttp.get(
            any(
                that: isA<Uri>()
                    .having((u) => u.path, 'path', '/kinetic_family/_changes')),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => _json({'results': [], 'last_seq': '0'}));

      final result = await sut.syncWithPeer(
          peer: _peer, client: couchClient, meshKey: _meshKey);

      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('push'));
      // Pull still completed (0 new docs, no error from pull side).
      expect(result.pulled, equals(0));
    });

    // -------------------------------------------------------------------------
    // upsertLocal
    // -------------------------------------------------------------------------

    test('upsertLocal stores doc and makes it visible via localDocs', () {
      final sut = CouchSyncService();
      sut.upsertLocal({'_id': 'task:new', 'title': 'Added locally'});
      expect(sut.localDocs.any((d) => d['_id'] == 'task:new'), isTrue);
    });

    test('upsertLocal overwrites existing doc with same _id', () {
      final sut = CouchSyncService(seedDocs: {
        'task:x': {'_id': 'task:x', 'v': 1}
      });
      sut.upsertLocal({'_id': 'task:x', 'v': 2});
      final doc = sut.localDocs.firstWhere((d) => d['_id'] == 'task:x');
      expect(doc['v'], equals(2));
    });
  });
}
