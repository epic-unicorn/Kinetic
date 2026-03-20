import 'package:equatable/equatable.dart';

/// The role a discovered peer plays on the family mesh.
enum PeerType {
  /// The always-on Docker home server running CouchDB.
  hub,

  /// A parent device.
  parent,

  /// A child kiosk device.
  child,
}

/// A CouchDB-capable peer discovered via mDNS on the local network.
class SyncPeer extends Equatable {
  final String deviceId;
  final String host;
  final int port;
  final PeerType type;

  const SyncPeer({
    required this.deviceId,
    required this.host,
    required this.port,
    required this.type,
  });

  /// Base URL of this peer's CouchDB instance, without trailing slash.
  String get couchDbUrl => 'http://$host:$port';

  @override
  List<Object?> get props => [deviceId, host, port, type];

  @override
  String toString() => 'SyncPeer(${type.name} "$deviceId" @ $host:$port)';
}
