import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'webdav_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockHttp;
  late WebDavClient client;

  setUp(() {
    mockHttp = MockClient();
    client = WebDavClient(
      baseUrl: 'https://dav.example.com',
      username: 'alice',
      password: 's3cret',
      httpClient: mockHttp,
    );
  });

  // ---------------------------------------------------------------------------
  // Auth header
  // ---------------------------------------------------------------------------

  test('GET sends correct Basic auth header', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response('hello', 200));

    await client.get('/kinetic/alice/tasks/task-1.ics');

    final captured = verify(
      mockHttp.get(any, headers: captureAnyNamed('headers')),
    ).captured.single as Map<String, String>;

    final expected = base64Encode(utf8.encode('alice:s3cret'));
    expect(captured['Authorization'], equals('Basic $expected'));
  });

  // ---------------------------------------------------------------------------
  // GET
  // ---------------------------------------------------------------------------

  test('GET returns body bytes on 200', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response.bytes(bytes, 200));

    final result = await client.get('/some/path');
    expect(result, equals(bytes));
  });

  test('GET throws WebDavException with statusCode 404', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response('Not Found', 404));

    try {
      await client.get('/missing');
      fail('expected WebDavException');
    } on WebDavException catch (e) {
      expect(e.statusCode, 404);
      expect(e.isNotFound, isTrue);
    }
  });

  // ---------------------------------------------------------------------------
  // PUT
  // ---------------------------------------------------------------------------

  test('PUT sends bytes and succeeds on 201', () async {
    when(mockHttp.put(any,
            headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => http.Response('', 201));

    final data = Uint8List.fromList([9, 8, 7]);
    await expectLater(client.put('/file.ics', data), completes);
  });

  test('PUT throws WebDavException on 412 Precondition Failed', () async {
    when(mockHttp.put(any,
            headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => http.Response('', 412));

    expect(
      () => client.put('/file.ics', Uint8List(0)),
      throwsA(isA<WebDavException>()),
    );
  });

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  test('DELETE succeeds on 204', () async {
    when(mockHttp.delete(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response('', 204));

    await expectLater(client.delete('/file.ics'), completes);
  });

  test('DELETE treats 404 as success', () async {
    when(mockHttp.delete(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response('', 404));

    await expectLater(client.delete('/nonexistent.ics'), completes);
  });

  test('DELETE throws on 500', () async {
    when(mockHttp.delete(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response('Server Error', 500));

    expect(() => client.delete('/file.ics'), throwsA(isA<WebDavException>()));
  });

  // ---------------------------------------------------------------------------
  // MKCOL
  // ---------------------------------------------------------------------------

  test('MKCOL treats 409 as success when collection already exists', () async {
    when(mockHttp.send(any)).thenAnswer((invocation) async {
      final request = invocation.positionalArguments[0] as http.BaseRequest;
      expect(request.method, 'MKCOL');
      return http.StreamedResponse(Stream.value([]), 409);
    });

    await expectLater(client.mkcol('/kinetic/shared/xp-reset'), completes);
  });

  // ---------------------------------------------------------------------------
  // WebDavSyncService.mergeTasks
  // ---------------------------------------------------------------------------

  group('WebDavSyncService.mergeTasks', () {
    ICalTask _task(String uid, DateTime updated,
            [ICalTaskStatus status = ICalTaskStatus.needsAction]) =>
        ICalTask(
          uid: uid,
          summary: 'Task $uid',
          createdAt: updated,
          updatedAt: updated,
          status: status,
        );

    test('remote-only task is adopted', () {
      final remote = _task('r1', DateTime.utc(2026, 1, 1));
      final result = WebDavSyncService.mergeTasks([], [remote]);
      expect(result.merged.length, equals(1));
      expect(result.toPush, isEmpty);
    });

    test('local-only task is kept and queued for push', () {
      final local = _task('l1', DateTime.utc(2026, 1, 1));
      final result = WebDavSyncService.mergeTasks([local], []);
      expect(result.merged.length, equals(1));
      expect(result.toPush, contains(local));
    });

    test('newer remote wins, local not pushed', () {
      final old = _task('t1', DateTime.utc(2026, 1, 1));
      final newer = _task('t1', DateTime.utc(2026, 1, 2));
      final result = WebDavSyncService.mergeTasks([old], [newer]);
      expect(result.merged.single.updatedAt, equals(newer.updatedAt));
      expect(result.toPush, isEmpty);
    });

    test('newer local wins and is queued for push', () {
      final old = _task('t1', DateTime.utc(2026, 1, 1));
      final newer = _task('t1', DateTime.utc(2026, 1, 2));
      final result = WebDavSyncService.mergeTasks([newer], [old]);
      expect(result.merged.single.updatedAt, equals(newer.updatedAt));
      expect(result.toPush, isNotEmpty);
    });

    test('same updatedAt → remote wins, local not pushed', () {
      final t = DateTime.utc(2026, 1, 1);
      final local = _task('t1', t);
      final remote = _task('t1', t, ICalTaskStatus.completed);
      final result = WebDavSyncService.mergeTasks([local], [remote]);
      expect(result.merged.single.status, equals(ICalTaskStatus.completed));
      expect(result.toPush, isEmpty);
    });
  });
}
