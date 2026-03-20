import 'dart:async';

import 'couch/couch_http_client.dart';
import 'couch/couch_sync_service.dart';
import 'discovery/mdns_discovery_service.dart';
import 'discovery/sync_peer.dart';

// ---------------------------------------------------------------------------
// Status model
// ---------------------------------------------------------------------------

enum SyncState { idle, syncing, error }

/// Snapshot of the orchestrator's current activity, emitted on [SyncOrchestrator.statusStream].
class SyncStatus {
  final SyncState state;
  final SyncPeer? peer;
  final SyncResult? lastResult;
  final String? errorMessage;

  const SyncStatus._({
    required this.state,
    this.peer,
    this.lastResult,
    this.errorMessage,
  });

  factory SyncStatus.idle() => const SyncStatus._(state: SyncState.idle);

  factory SyncStatus.syncing(SyncPeer peer) =>
      SyncStatus._(state: SyncState.syncing, peer: peer);

  factory SyncStatus.done(SyncPeer peer, SyncResult result) =>
      SyncStatus._(state: SyncState.idle, peer: peer, lastResult: result);

  factory SyncStatus.error(String message) =>
      SyncStatus._(state: SyncState.error, errorMessage: message);

  @override
  String toString() => switch (state) {
    SyncState.idle => lastResult != null ? 'idle (last: $lastResult)' : 'idle',
    SyncState.syncing => 'syncing with ${peer?.deviceId}',
    SyncState.error => 'error: $errorMessage',
  };
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

/// Ties mDNS peer discovery to the CouchDB sync service.
///
/// **Lifecycle:**
/// ```dart
/// final orchestrator = SyncOrchestrator(
///   discoveryService : BonsoirMdnsDiscoveryService(),
///   syncService      : CouchSyncService(),
///   meshKey          : plan.meshKeyBytes,
///   credentials      : ('kinetic', 'secret'), // optional CouchDB basic-auth
/// );
///
/// orchestrator.statusStream.listen(print);
/// await orchestrator.start();   // begins mDNS discovery + periodic sync
/// // ...
/// await orchestrator.stop();
/// orchestrator.dispose();
/// ```
///
/// **Topology:** Hub-and-spoke for Phase 2.
/// Any `_kinetic._tcp` service discovered via mDNS triggers an immediate
/// sync cycle, followed by a periodic heartbeat every 30 s.
class SyncOrchestrator {
  static const _heartbeatInterval = Duration(seconds: 30);

  final MdnsDiscoveryService _discovery;
  final CouchSyncService _syncService;
  final List<int> _meshKey;
  final ({String username, String password})? _credentials;

  final StreamController<SyncStatus> _statusCtrl =
      StreamController<SyncStatus>.broadcast();

  /// Observable stream of sync activity updates.
  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  final Map<String, SyncPeer> _peers = {};
  StreamSubscription<SyncPeer>? _discoverySub;
  Timer? _heartbeat;

  SyncOrchestrator({
    required MdnsDiscoveryService discoveryService,
    required CouchSyncService syncService,
    required List<int> meshKey,
    ({String username, String password})? credentials,
  }) : _discovery = discoveryService,
       _syncService = syncService,
       _meshKey = meshKey,
       _credentials = credentials;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts mDNS discovery and the periodic sync heartbeat.
  Future<void> start() async {
    await _discovery.startDiscovery();
    _discoverySub = _discovery.peerStream.listen(_onPeerFound);
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _syncAll());
    _statusCtrl.add(SyncStatus.idle());
  }

  /// Stops discovery and cancels the heartbeat.  Does not call [dispose].
  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery.stopDiscovery();
  }

  /// Stops and releases the status [StreamController].  Call once only.
  void dispose() {
    stop();
    _discovery.dispose();
    _statusCtrl.close();
  }

  // ---------------------------------------------------------------------------
  // Sync logic
  // ---------------------------------------------------------------------------

  void _onPeerFound(SyncPeer peer) {
    _peers[peer.deviceId] = peer;
    _syncWithPeer(peer); // immediate sync on discovery
  }

  Future<void> _syncAll() async {
    for (final peer in List<SyncPeer>.from(_peers.values)) {
      await _syncWithPeer(peer);
    }
  }

  Future<void> _syncWithPeer(SyncPeer peer) async {
    if (_statusCtrl.isClosed) return;
    _statusCtrl.add(SyncStatus.syncing(peer));

    final client = CouchHttpClient(
      host: peer.host,
      port: peer.port,
      username: _credentials?.username,
      password: _credentials?.password,
    );

    try {
      final result = await _syncService.syncWithPeer(
        peer: peer,
        client: client,
        meshKey: _meshKey,
      );
      if (!_statusCtrl.isClosed) {
        _statusCtrl.add(SyncStatus.done(peer, result));
      }
    } catch (e) {
      if (!_statusCtrl.isClosed) {
        _statusCtrl.add(
          SyncStatus.error('sync with ${peer.deviceId} failed: $e'),
        );
      }
    } finally {
      client.close();
    }
  }
}
