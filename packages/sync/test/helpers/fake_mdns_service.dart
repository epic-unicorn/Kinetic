import 'dart:async';

import 'package:kinetic_sync/kinetic_sync.dart';

/// In-memory [MdnsDiscoveryService] for unit tests.
/// Exposes a [emitPeer] helper to push peers into the stream manually.
class FakeMdnsDiscoveryService implements MdnsDiscoveryService {
  final StreamController<SyncPeer> _ctrl =
      StreamController<SyncPeer>.broadcast();

  bool started = false;
  bool stopped = false;
  bool disposed = false;

  @override
  Stream<SyncPeer> get peerStream => _ctrl.stream;

  @override
  Future<void> startDiscovery() async => started = true;

  @override
  Future<void> stopDiscovery() async => stopped = true;

  @override
  void dispose() {
    disposed = true;
    _ctrl.close();
  }

  /// Push a peer into [peerStream] as if mDNS resolved it.
  void emitPeer(SyncPeer peer) => _ctrl.add(peer);
}
