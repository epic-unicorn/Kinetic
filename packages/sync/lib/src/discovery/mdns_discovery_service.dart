import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'sync_peer.dart';

// ---------------------------------------------------------------------------
// Abstract interface — injected into SyncOrchestrator, mockable in tests.
// ---------------------------------------------------------------------------

/// Discovers Kinetic Link peers (hubs and devices) on the local network.
abstract class MdnsDiscoveryService {
  /// Emits a [SyncPeer] each time a Kinetic CouchDB node is resolved.
  Stream<SyncPeer> get peerStream;

  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  void dispose();
}

// ---------------------------------------------------------------------------
// Production implementation — Bonsoir (Android NSD / iOS Bonjour)
// ---------------------------------------------------------------------------

/// mDNS service type advertised by both the Docker hub and peer devices.
const _kServiceType = '_kinetic._tcp';

/// Discovers `_kinetic._tcp` services on the LAN using the Bonsoir plugin.
///
/// The Docker CouchDB hub registers itself via avahi inside the container
/// (configured in Phase 5). This class purely consumes those registrations.
///
/// **Android permissions required in AndroidManifest.xml:**
/// ```xml
/// <uses-permission android:name="android.permission.INTERNET" />
/// <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
/// <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
/// <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
/// ```
class BonsoirMdnsDiscoveryService implements MdnsDiscoveryService {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  final StreamController<SyncPeer> _controller =
      StreamController<SyncPeer>.broadcast();

  @override
  Stream<SyncPeer> get peerStream => _controller.stream;

  @override
  Future<void> startDiscovery() async {
    _discovery = BonsoirDiscovery(type: _kServiceType);
    // Bonsoir 6.x: use initialize() instead of awaiting a `ready` Future.
    await _discovery!.initialize();
    _sub = _discovery!.eventStream?.listen(_handleEvent);
    await _discovery!.start();
  }

  @override
  Future<void> stopDiscovery() async {
    await _sub?.cancel();
    await _discovery?.stop();
    _sub = null;
    _discovery = null;
  }

  @override
  void dispose() {
    stopDiscovery();
    _controller.close();
  }

  void _handleEvent(BonsoirDiscoveryEvent event) {
    // Bonsoir 6.x uses sealed subclasses instead of an enum `type` field.
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      // Trigger async host/IP resolution; BonsoirDiscoveryServiceResolvedEvent
      // will follow once the service resolver completes.
      _discovery?.serviceResolver.resolveService(event.service);
      return;
    }

    if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final service = event.service;
      final deviceId = service.attributes['id'];
      final roleStr = service.attributes['role'] ?? 'hub';

      if (deviceId == null) return;

      // After resolution, BonsoirService.host is populated with IP/hostname.
      final host = service.host ?? 'localhost';

      PeerType type;
      try {
        type = PeerType.values.byName(roleStr);
      } catch (_) {
        type = PeerType.hub;
      }

      _controller.add(
        SyncPeer(
            deviceId: deviceId, host: host, port: service.port, type: type),
      );
    }
  }
}
