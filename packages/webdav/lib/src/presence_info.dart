import 'dart:convert';

/// Represents a family member's last-known sync presence.
///
/// Stored on WebDAV as `/kinetic/shared/presence/{deviceId}.json`,
/// encrypted with the family key.
class PresenceInfo {
  /// Stable device identifier — parent's [SyncConfig.parentId] or kid's ID.
  final String deviceId;

  /// `'parent'` or `'kid'`.
  final String deviceType;

  /// Human-readable name (WebDAV username for parents, kid name for kids).
  final String displayName;

  /// UTC timestamp of the most recent successful sync.
  final DateTime lastSeen;

  const PresenceInfo({
    required this.deviceId,
    required this.deviceType,
    required this.displayName,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceType': deviceType,
        'displayName': displayName,
        'lastSeen': lastSeen.toUtc().toIso8601String(),
      };

  factory PresenceInfo.fromJson(Map<String, dynamic> json) => PresenceInfo(
        deviceId: json['deviceId'] as String,
        deviceType: json['deviceType'] as String,
        displayName: json['displayName'] as String? ?? '',
        lastSeen: DateTime.parse(json['lastSeen'] as String),
      );

  static PresenceInfo? tryFromJson(Map<String, dynamic> json) {
    try {
      return PresenceInfo.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

/// Represents an explicit disconnect event written by a device before
/// it removes itself from the family.
///
/// Stored on WebDAV as `/kinetic/shared/disconnect/{deviceId}.json`,
/// encrypted with the family key.
class DisconnectTombstone {
  final String deviceId;
  final String deviceType;
  final DateTime disconnectedAt;

  const DisconnectTombstone({
    required this.deviceId,
    required this.deviceType,
    required this.disconnectedAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceType': deviceType,
        'disconnectedAt': disconnectedAt.toUtc().toIso8601String(),
      };

  factory DisconnectTombstone.fromJson(Map<String, dynamic> json) =>
      DisconnectTombstone(
        deviceId: json['deviceId'] as String,
        deviceType: json['deviceType'] as String? ?? 'unknown',
        disconnectedAt: DateTime.parse(json['disconnectedAt'] as String),
      );
}
