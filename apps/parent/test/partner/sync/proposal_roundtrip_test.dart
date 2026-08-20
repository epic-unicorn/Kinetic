import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/sync/sync_orchestrator.dart';
import 'package:parent/todo/models/enums.dart';
import '../../helpers/fake_http_client.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Fixed 32-byte test keys (AES-256).  All devices share the same family key
// to simulate a real enrollment where the key was exchanged via QR code.
// ---------------------------------------------------------------------------

final _personalKeyA = Uint8List.fromList(List.generate(32, (i) => i + 1));
final _personalKeyB = Uint8List.fromList(List.generate(32, (i) => i + 100));
final _familyKey = Uint8List.fromList(List.generate(32, (i) => i + 50));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [SyncOrchestrator] backed by [storage].
///
/// [parentId] is intentionally empty in most tests so auto-proposal generation
/// is skipped (avoids needing real task data for that branch).
(SyncOrchestrator, WebDavSyncService) _makeOrchestrator(
  AppDatabase db,
  SharedStorage storage, {
  String username = 'testuser',
  String parentId = '',
  required Uint8List personalKey,
}) {
  final config = SyncConfig(
    serverUrl: 'https://fake-dav',
    username: username,
    password: 'pass',
    parentId: parentId,
    personalKeyBytes: personalKey,
    familyKeyBytes: _familyKey,
  );
  final client = WebDavClient(
    baseUrl: config.baseUrl,
    username: config.username,
    password: config.password,
    httpClient: FakeHttpClient(storage),
  );
  final service = WebDavSyncService(client: client, config: config);
  final orchestrator = SyncOrchestrator(db: db, config: config);
  return (orchestrator, service);
}

/// Inserts a raw [PartnerProposalRow] with dirty syncState into [db].
Future<void> _insertDirtyProposal(
  AppDatabase db, {
  required String id,
  required String fromParentId,
  required String taskTitle,
  String status = 'pending',
}) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.partnerProposals)
      .insert(
        PartnerProposalsCompanion.insert(
          id: id,
          fromParentId: fromParentId,
          taskTitle: taskTitle,
          status: Value(status),
          syncState: const Value('dirty'),
          receivedAt: now,
          updatedAt: now,
        ),
      );
}

/// Returns the raw DB row for a proposal.
Future<PartnerProposalRow?> _getRow(AppDatabase db, String id) async {
  return (db.select(
    db.partnerProposals,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Proposal round-trip integration tests', () {
    late SharedStorage storage;
    late AppDatabase dbA;
    late AppDatabase dbB;
    late SyncOrchestrator orchestratorA;
    late SyncOrchestrator orchestratorB;
    late WebDavSyncService serviceA;
    late WebDavSyncService serviceB;

    setUp(() {
      storage = SharedStorage();
      dbA = createTestDatabase();
      dbB = createTestDatabase();

      (orchestratorA, serviceA) = _makeOrchestrator(
        dbA,
        storage,
        username: 'alice',
        personalKey: _personalKeyA,
      );
      (orchestratorB, serviceB) = _makeOrchestrator(
        dbB,
        storage,
        username: 'bob',
        personalKey: _personalKeyB,
      );
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    // ── Basic push / pull ────────────────────────────────────────────────────

    test('proposal created on A appears in B after both sync', () async {
      // A inserts a dirty proposal (as-if it was created manually or via service).
      await _insertDirtyProposal(
        dbA,
        id: 'prop-1',
        fromParentId: 'parent-a',
        taskTitle: 'Boodschappen doen',
      );

      // A syncs — this pushes the dirty proposal to shared storage.
      await orchestratorA.syncWithService(serviceA);

      // Verify the proposal was stored in the shared fake storage.
      final storedInSharedStorage = storage
          .listChildren('/kinetic/shared/proposals')
          .toList();
      expect(
        storedInSharedStorage,
        anyElement(contains('prop-1')),
        reason:
            'After A syncs, the proposal must be in shared storage. '
            'Files found: $storedInSharedStorage',
      );

      // B syncs — this pulls the proposal from shared storage.
      await orchestratorB.syncWithService(serviceB);

      // Check if B can independently read from storage.
      final rawBytesInStorage = storage.get(
        '/kinetic/shared/proposals/prop-1.json',
      );
      expect(
        rawBytesInStorage,
        isNotNull,
        reason: 'Storage should still have the file after B syncs',
      );

      // Verify stored bytes are non-empty and can be decrypted.
      expect(
        rawBytesInStorage!.isNotEmpty,
        isTrue,
        reason: 'Bytes in storage are empty',
      );
      final decryptedStoredBytes = await KineticEncryption.decrypt(
        rawBytesInStorage,
        _familyKey,
      );
      expect(
        decryptedStoredBytes.isNotEmpty,
        isTrue,
        reason: 'Stored bytes cannot be decrypted',
      );

      // Verify that B's WebDavClient.get returns the same bytes as storage.
      final clientGetBytes = await serviceB.client.get(
        '/kinetic/shared/proposals/prop-1.json',
      );
      expect(
        clientGetBytes,
        equals(rawBytesInStorage),
        reason:
            'client.get should return same bytes as storage '
            'stored=${rawBytesInStorage.length} got=${clientGetBytes.length}',
      );

      // Verify B's family key matches.
      expect(
        serviceB.config.familyKeyBytes,
        equals(_familyKey),
        reason: 'serviceB must use the same family key as _familyKey',
      );

      // Directly verify B's service can pull proposals.
      final directPull = await serviceB.pullProposals();
      expect(
        directPull,
        hasLength(1),
        reason:
            'serviceB.pullProposals() should return 1 proposal. '
            'Returned: ${directPull.length}',
      );

      // Proposal must now be in B's database.
      final row = await _getRow(dbB, 'prop-1');
      expect(row, isNotNull);
      expect(row!.taskTitle, equals('Boodschappen doen'));
      expect(row.fromParentId, equals('parent-a'));
      expect(row.status, equals('pending'));
    });

    test('after A syncs, local proposal is marked clean', () async {
      await _insertDirtyProposal(
        dbA,
        id: 'prop-2',
        fromParentId: 'parent-a',
        taskTitle: 'Test',
      );
      await orchestratorA.syncWithService(serviceA);

      final row = await _getRow(dbA, 'prop-2');
      expect(row?.syncState, equals('clean'));
    });

    test('multiple proposals from A all appear in B', () async {
      for (var i = 0; i < 3; i++) {
        await _insertDirtyProposal(
          dbA,
          id: 'prop-$i',
          fromParentId: 'parent-a',
          taskTitle: 'Taak $i',
        );
      }

      await orchestratorA.syncWithService(serviceA);
      await orchestratorB.syncWithService(serviceB);

      for (var i = 0; i < 3; i++) {
        final row = await _getRow(dbB, 'prop-$i');
        expect(row, isNotNull, reason: 'prop-$i should be in B');
      }
    });

    // ── Status update round-trip ─────────────────────────────────────────────

    test(
      'B accepts proposal and A sees accepted status after next sync',
      () async {
        // A pushes proposal, B gets it.
        await _insertDirtyProposal(
          dbA,
          id: 'prop-accept',
          fromParentId: 'parent-a',
          taskTitle: 'Ophalen kinderen',
        );
        await orchestratorA.syncWithService(serviceA);
        await orchestratorB.syncWithService(serviceB);

        // B accepts the proposal (marks it dirty with status='accepted').
        await (dbB.update(
          dbB.partnerProposals,
        )..where((t) => t.id.equals('prop-accept'))).write(
          PartnerProposalsCompanion(
            status: const Value('accepted'),
            syncState: const Value('dirty'),
            updatedAt: Value(
              DateTime.now().toUtc().add(const Duration(seconds: 1)),
            ),
          ),
        );

        // B syncs — pushes the acceptance back to shared storage.
        await orchestratorB.syncWithService(serviceB);

        // A syncs — pulls the updated proposal.
        await orchestratorA.syncWithService(serviceA);

        final rowA = await _getRow(dbA, 'prop-accept');
        expect(rowA?.status, equals('accepted'));
      },
    );

    test(
      'B dismisses proposal and A sees dismissed status after sync',
      () async {
        await _insertDirtyProposal(
          dbA,
          id: 'prop-dismiss',
          fromParentId: 'parent-a',
          taskTitle: 'Huishoudelijke klus',
        );
        await orchestratorA.syncWithService(serviceA);
        await orchestratorB.syncWithService(serviceB);

        // B dismisses (slightly later timestamp → B wins LWW).
        await (dbB.update(
          dbB.partnerProposals,
        )..where((t) => t.id.equals('prop-dismiss'))).write(
          PartnerProposalsCompanion(
            status: const Value('dismissed'),
            syncState: const Value('dirty'),
            updatedAt: Value(
              DateTime.now().toUtc().add(const Duration(seconds: 2)),
            ),
          ),
        );

        await orchestratorB.syncWithService(serviceB);
        await orchestratorA.syncWithService(serviceA);

        final rowA = await _getRow(dbA, 'prop-dismiss');
        expect(rowA?.status, equals('dismissed'));
      },
    );

    // ── Last-write-wins conflict resolution ──────────────────────────────────

    test(
      'LWW: later updatedAt wins when both sides update same proposal',
      () async {
        // Seed both devices with the same proposal (clean on both sides).
        final baseTime = DateTime.utc(2026, 4, 1, 12, 0, 0);
        final companion = PartnerProposalsCompanion.insert(
          id: 'prop-lww',
          fromParentId: 'parent-a',
          taskTitle: 'Conflicterende taak',
          status: const Value('pending'),
          syncState: const Value('clean'),
          receivedAt: baseTime,
          updatedAt: baseTime,
        );
        await dbA.into(dbA.partnerProposals).insert(companion);
        await dbB.into(dbB.partnerProposals).insert(companion);

        // A updates at T+1 → 'dismissed'.
        await (dbA.update(
          dbA.partnerProposals,
        )..where((t) => t.id.equals('prop-lww'))).write(
          PartnerProposalsCompanion(
            status: const Value('dismissed'),
            syncState: const Value('dirty'),
            updatedAt: Value(baseTime.add(const Duration(seconds: 1))),
          ),
        );

        // B updates at T+2 → 'accepted' (newer → should win).
        await (dbB.update(
          dbB.partnerProposals,
        )..where((t) => t.id.equals('prop-lww'))).write(
          PartnerProposalsCompanion(
            status: const Value('accepted'),
            syncState: const Value('dirty'),
            updatedAt: Value(baseTime.add(const Duration(seconds: 2))),
          ),
        );

        // Both sync — B pushes last (later timestamp wins on server).
        await orchestratorA.syncWithService(serviceA);
        await orchestratorB.syncWithService(serviceB);

        // Both pull — should both see 'accepted' (B's update).
        await orchestratorA.syncWithService(serviceA);
        await orchestratorB.syncWithService(serviceB);

        final rowA = await _getRow(dbA, 'prop-lww');
        final rowB = await _getRow(dbB, 'prop-lww');
        // The later writer (B at T+2) must win on both devices.
        expect(rowA?.status, equals('accepted'));
        expect(rowB?.status, equals('accepted'));
      },
    );

    // ── Wrong family key ─────────────────────────────────────────────────────

    test(
      'device with wrong family key cannot read proposals from server',
      () async {
        // A pushes a proposal encrypted with the shared family key.
        await _insertDirtyProposal(
          dbA,
          id: 'prop-key',
          fromParentId: 'parent-a',
          taskTitle: 'Beschermd voorstel',
        );
        await orchestratorA.syncWithService(serviceA);

        // C uses a *different* family key — decryption must fail silently.
        final wrongKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));
        final dbC = createTestDatabase();
        addTearDown(dbC.close);

        final configC = SyncConfig(
          serverUrl: 'https://fake-dav',
          username: 'carol',
          password: 'pass',
          parentId: '',
          personalKeyBytes: _personalKeyA,
          familyKeyBytes: wrongKey,
        );
        final clientC = WebDavClient(
          baseUrl: configC.baseUrl,
          username: configC.username,
          password: configC.password,
          httpClient: FakeHttpClient(storage),
        );
        final serviceC = WebDavSyncService(client: clientC, config: configC);
        final orchestratorC = SyncOrchestrator(db: dbC, config: configC);

        await orchestratorC.syncWithService(serviceC);

        // C must NOT have the proposal (decryption failed → skipped).
        final row = await _getRow(dbC, 'prop-key');
        expect(row, isNull);
      },
    );

    // ── Idempotency ───────────────────────────────────────────────────────────

    test('syncing multiple times does not duplicate proposals', () async {
      await _insertDirtyProposal(
        dbA,
        id: 'prop-idem',
        fromParentId: 'parent-a',
        taskTitle: 'Idempotente taak',
      );
      await orchestratorA.syncWithService(serviceA);

      // B syncs three times — should end up with exactly one row.
      await orchestratorB.syncWithService(serviceB);
      await orchestratorB.syncWithService(serviceB);
      await orchestratorB.syncWithService(serviceB);

      final rows = await (dbB.select(
        dbB.partnerProposals,
      )..where((t) => t.id.equals('prop-idem'))).get();
      expect(rows, hasLength(1));
    });

    // ── Low-level sanity tests ───────────────────────────────────────────────

    group('FakeHttpClient and WebDavSyncService low-level sanity', () {
      late SharedStorage storage;
      late WebDavSyncService service;

      setUp(() {
        storage = SharedStorage();
        final config = SyncConfig(
          serverUrl: 'https://fake',
          username: 'test',
          password: 'pass',
          parentId: '',
          personalKeyBytes: _personalKeyA,
          familyKeyBytes: _familyKey,
        );
        final client = WebDavClient(
          baseUrl: config.baseUrl,
          username: config.username,
          password: config.password,
          httpClient: FakeHttpClient(storage),
        );
        service = WebDavSyncService(client: client, config: config);
      });

      test('PUT then GET via FakeHttpClient returns original bytes', () async {
        final bytes = Uint8List.fromList([10, 20, 30, 40, 50]);
        await service.client.put('/test/file.bin', bytes);

        final retrieved = await service.client.get('/test/file.bin');
        expect(retrieved, equals(bytes));
      });

      test('FakeHttpClient PROPFIND raw body contains hrefs', () async {
        storage.put(
          '/kinetic/shared/proposals/p1.json',
          Uint8List.fromList([1]),
        );
        storage.put(
          '/kinetic/shared/proposals/p2.json',
          Uint8List.fromList([2]),
        );

        final rawClient = FakeHttpClient(storage);
        final req = http.Request(
          'PROPFIND',
          Uri.parse('https://fake/kinetic/shared/proposals/'),
        )..body = '';
        final resp = await rawClient.send(req);
        final body = await resp.stream.bytesToString();
        expect(
          body,
          contains('<d:href>'),
          reason: 'Raw PROPFIND body must contain hrefs. body=[[$body]]',
        );
      });

      test('PROPFIND lists stored files', () async {
        storage.put(
          '/kinetic/shared/proposals/p1.json',
          Uint8List.fromList([1]),
        );
        storage.put(
          '/kinetic/shared/proposals/p2.json',
          Uint8List.fromList([2]),
        );

        // Sanity check: storage has 2 files
        final storageChildren = storage
            .listChildren('/kinetic/shared/proposals/')
            .toList();
        expect(
          storageChildren,
          hasLength(2),
          reason: 'storage.listChildren must find 2 files before PROPFIND',
        );

        // Direct PROPFIND via the WebDavClient
        final entries = await service.client.propfind(
          '/kinetic/shared/proposals',
        );
        expect(
          entries.length,
          greaterThan(0),
          reason:
              'PROPFIND must return at least 1 entry. '
              'storageChildren=$storageChildren. '
              'entries.map(href)=${entries.map((e) => e.href).toList()}',
        );

        final jsonEntries = entries
            .where((e) => e.href.endsWith('.json'))
            .toList();
        expect(jsonEntries, hasLength(2));
      });

      test('pushProposal then pullProposals round-trips the JSON', () async {
        final json = {
          'id': 'test-id',
          'fromParentId': 'parent-a',
          'taskTitle': 'Test taak',
          'taskNotes': null,
          'taskCategory': 'household',
          'taskPriority': 0,
          'taskDueDate': null,
          'status': 'pending',
          'receivedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'autoGenerated': false,
        };

        await service.pushProposal(json);
        final pulled = await service.pullProposals();

        expect(pulled, hasLength(1));
        expect(pulled.first['id'], equals('test-id'));
        expect(pulled.first['taskTitle'], equals('Test taak'));
      });
    });

    test('task category and priority survive the round-trip', () async {
      final now = DateTime.now().toUtc();
      await dbA
          .into(dbA.partnerProposals)
          .insert(
            PartnerProposalsCompanion.insert(
              id: 'prop-meta',
              fromParentId: 'parent-a',
              taskTitle: 'Belasting aangifte',
              taskCategory: const Value('finance'),
              taskPriority: const Value(3), // TaskPriority.high
              syncState: const Value('dirty'),
              receivedAt: now,
              updatedAt: now,
            ),
          );

      await orchestratorA.syncWithService(serviceA);
      await orchestratorB.syncWithService(serviceB);

      final row = await _getRow(dbB, 'prop-meta');
      expect(row?.taskCategory, equals(TaskCategory.finance.name));
      expect(row?.taskPriority, equals(TaskPriority.high.index));
    });
  });
}
