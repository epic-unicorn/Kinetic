import 'dart:convert';
import 'dart:math';

import '../models/family_member.dart';
import 'identity_service.dart';

/// Encodes and decodes QR pairing payloads for peer discovery.
///
/// **Two-step pairing flow:**
/// 1. Device A calls [generatePairingPayload] → displays QR code.
/// 2. Device B scans → calls [parsePairingPayload] → learns A's public key
///    and the shared mesh encryption key.
/// 3. Device B then shows its own QR → Device A scans to complete the exchange.
///
/// The payload is intentionally compact (base64-encoded JSON, ~360–400 chars)
/// so it fits comfortably inside a standard QR code at medium error correction.
class PairingService {
  static const int _payloadVersion = 1;

  final IdentityService _identityService;

  PairingService({required IdentityService identityService})
      : _identityService = identityService;

  /// Generates a base64-encoded pairing payload for display as a QR code.
  ///
  /// Each call produces a **fresh 32-byte mesh key**. The first device to
  /// initiate pairing owns the mesh key and distributes it to all peers.
  Future<String> generatePairingPayload({
    required String deviceLabel,
    required MemberRole role,
  }) async {
    final identity = await _identityService.getOrCreateIdentity();
    final meshKey = _generateSecureMeshKey();

    final payload = {
      'v': _payloadVersion,
      'id': identity.deviceId,
      'pk': identity.publicKeyBase64,
      'mk': base64Encode(meshKey),
      'role': role.name,
      'label': deviceLabel,
    };

    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  /// Parses a raw base64 string scanned from a QR code.
  ///
  /// Throws [FormatException] if the payload is malformed or carries an
  /// unsupported version number.
  PairingData parsePairingPayload(String base64Payload) {
    try {
      final jsonString = utf8.decode(base64Decode(base64Payload));
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      final version = map['v'];
      if (version != _payloadVersion) {
        throw FormatException('Unsupported pairing payload version: $version');
      }

      return PairingData(
        deviceId: map['id'] as String,
        publicKeyBase64: map['pk'] as String,
        meshKeyBase64: map['mk'] as String,
        role: MemberRole.values.byName(map['role'] as String),
        label: map['label'] as String,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid pairing payload: $e');
    }
  }

  List<int> _generateSecureMeshKey() {
    final rng = Random.secure();
    return List<int>.generate(32, (_) => rng.nextInt(256));
  }
}

/// Data extracted from a successfully parsed pairing QR code.
class PairingData {
  final String deviceId;
  final String publicKeyBase64;

  /// 32-byte AES-256 mesh encryption key, base64-encoded.
  final String meshKeyBase64;
  final MemberRole role;
  final String label;

  const PairingData({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.meshKeyBase64,
    required this.role,
    required this.label,
  });

  /// Converts this pairing data into a trusted [FamilyMember] record.
  FamilyMember toFamilyMember() => FamilyMember(
        id: deviceId,
        publicKeyBase64: publicKeyBase64,
        name: label,
        role: role,
        createdAt: DateTime.now().toUtc(),
      );
}
