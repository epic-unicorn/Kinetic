import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:parent/family/family_connection_service.dart';
import 'package:parent/settings/models/enrolled_kid.dart';

void main() {
  group('FamilyConnectionService', () {
    test('partner is connected when seen within 7 days', () {
      final status = FamilyConnectionService.partnerStatus(
        partnerPaired: true,
        presenceList: [
          PresenceInfo(
            deviceId: 'partner-1',
            deviceType: 'parent',
            displayName: 'Emma',
            lastSeen: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      );
      expect(status, isNotNull);
      expect(status!.isConnected, isTrue);
      expect(status.isStale, isFalse);
    });

    test('kid is offline when last seen over 14 days ago', () {
      final statuses = FamilyConnectionService.kidStatuses(
        enrolledKids: [
          EnrolledKid(
            id: 'kid-1',
            name: 'Lucas',
            enrolledAt: DateTime(2026, 1, 1),
          ),
        ],
        presenceList: [
          PresenceInfo(
            deviceId: 'kid-1',
            deviceType: 'kid',
            displayName: 'Lucas',
            lastSeen: DateTime.now().subtract(const Duration(days: 20)),
          ),
        ],
      );
      expect(statuses.single.isConnected, isFalse);
    });

    test('allows send when partner is connected', () {
      final partner = FamilyMemberStatus(
        id: 'p1',
        name: 'Emma',
        type: FamilyMemberType.partner,
        isConnected: true,
        isStale: false,
        lastSeen: DateTime.now(),
      );
      expect(
        FamilyConnectionService.canSend(partner: partner, kids: const []),
        isTrue,
      );
    });

    test('falls back to connected when presence unavailable', () {
      final statuses = FamilyConnectionService.kidStatuses(
        enrolledKids: [
          EnrolledKid(
            id: 'kid-1',
            name: 'Lucas',
            enrolledAt: DateTime(2026, 1, 1),
          ),
        ],
        presenceList: const [],
        allowWithoutPresence: true,
      );
      expect(statuses.single.isConnected, isTrue);
      expect(statuses.single.isStale, isTrue);
    });
  });
}
