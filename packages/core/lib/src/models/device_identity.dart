import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Immutable snapshot of this device's cryptographic identity.
///
/// [deviceId]       — stable UUID written once to secure storage.
/// [publicKeyBytes] — 32-byte Ed25519 public key; safe to share.
/// [keyPair]        — in-memory handle for signing; never serialised directly.
class DeviceIdentity {
  final String deviceId;
  final List<int> publicKeyBytes;

  /// Live key-pair handle — not serialised; reconstructed from stored seed on startup.
  final SimpleKeyPair keyPair;

  const DeviceIdentity({
    required this.deviceId,
    required this.publicKeyBytes,
    required this.keyPair,
  });

  /// Base64-encoded public key, suitable for inclusion in a pairing payload.
  String get publicKeyBase64 => base64Encode(publicKeyBytes);

  @override
  bool operator ==(Object other) =>
      other is DeviceIdentity && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}
