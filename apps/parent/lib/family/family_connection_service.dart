import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../l10n/generated/app_localizations.dart';
import '../settings/models/enrolled_kid.dart';

enum FamilyMemberType { partner, kid }

/// Connection state for a family member eligible for task delegation.
class FamilyMemberStatus {
  final String id;
  final String name;
  final FamilyMemberType type;
  final bool isConnected;
  final bool isStale;
  final DateTime? lastSeen;

  const FamilyMemberStatus({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
    required this.isStale,
    this.lastSeen,
  });

  String statusLabel(AppLocalizations l10n) =>
      FamilyConnectionService.formatStatus(
        isConnected: isConnected,
        isStale: isStale,
        lastSeen: lastSeen,
        l10n: l10n,
      );
}

/// Evaluates partner/kid connectivity from enrollment flags and presence data.
class FamilyConnectionService {
  static const connectedThreshold = Duration(days: 7);
  static const staleThreshold = Duration(days: 14);

  static FamilyMemberStatus? partnerStatus({
    required bool partnerPaired,
    required List<PresenceInfo> presenceList,
    DateTime? now,
    bool allowWithoutPresence = false,
  }) {
    if (!partnerPaired) return null;
    final clock = now ?? DateTime.now();
    PresenceInfo? partnerPresence;
    for (final p in presenceList) {
      if (p.deviceType == 'parent') {
        partnerPresence = p;
        break;
      }
    }
    final lastSeen = partnerPresence?.lastSeen;
    final (connected, stale) = _evaluate(
      lastSeen,
      clock,
      allowWithoutPresence: allowWithoutPresence,
    );
    return FamilyMemberStatus(
      id: partnerPresence?.deviceId ?? 'partner',
      name: partnerPresence?.displayName ?? 'Partner',
      type: FamilyMemberType.partner,
      isConnected: connected,
      isStale: stale,
      lastSeen: lastSeen,
    );
  }

  static List<FamilyMemberStatus> kidStatuses({
    required List<EnrolledKid> enrolledKids,
    required List<PresenceInfo> presenceList,
    DateTime? now,
    bool allowWithoutPresence = false,
  }) {
    final clock = now ?? DateTime.now();
    final byId = {for (final p in presenceList) p.deviceId: p};
    return [
      for (final kid in enrolledKids)
        () {
          final presence = byId[kid.id];
          final lastSeen = presence?.lastSeen;
          final (connected, stale) = _evaluate(
            lastSeen,
            clock,
            allowWithoutPresence: allowWithoutPresence,
          );
          return FamilyMemberStatus(
            id: kid.id,
            name: kid.name,
            type: FamilyMemberType.kid,
            isConnected: connected,
            isStale: stale,
            lastSeen: lastSeen,
          );
        }(),
    ];
  }

  static bool canSend({
    FamilyMemberStatus? partner,
    required List<FamilyMemberStatus> kids,
  }) {
    if (partner?.isConnected == true) return true;
    return kids.any((k) => k.isConnected);
  }

  static String formatStatus({
    required bool isConnected,
    required bool isStale,
    DateTime? lastSeen,
    required AppLocalizations l10n,
  }) {
    if (!isConnected) {
      if (lastSeen == null) return l10n.connNotConnected;
      return l10n.connNotConnectedSince(
        _formatLastSeen(DateTime.now(), lastSeen, l10n),
      );
    }
    if (isStale && lastSeen == null) return l10n.connUnknownNoSync;
    if (isStale) {
      return l10n.connStale(_formatLastSeen(DateTime.now(), lastSeen!, l10n));
    }
    if (lastSeen == null) return l10n.connConnected;
    return l10n.connConnectedSince(
      _formatLastSeen(DateTime.now(), lastSeen, l10n),
    );
  }

  static (bool connected, bool stale) _evaluate(
    DateTime? lastSeen,
    DateTime now, {
    bool allowWithoutPresence = false,
  }) {
    if (lastSeen == null) {
      if (allowWithoutPresence) return (true, true);
      return (false, false);
    }
    final diff = now.difference(lastSeen.toLocal());
    if (diff > staleThreshold) return (false, true);
    if (diff > connectedThreshold) return (true, true);
    return (true, false);
  }

  static String _formatLastSeen(
    DateTime now,
    DateTime lastSeen,
    AppLocalizations l10n,
  ) {
    final diff = now.difference(lastSeen.toLocal());
    if (diff.inMinutes < 1) return l10n.relativeJustNow;
    if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.relativeDaysAgo(diff.inDays);
    return l10n.relativeWeeksAgo(diff.inDays ~/ 7);
  }
}
