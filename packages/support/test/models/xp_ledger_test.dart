import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_support/kinetic_support.dart';

void main() {
  group('XpLedger.empty', () {
    test('starts with balance 0 and no events', () {
      final ledger = XpLedger.empty('member-001');
      expect(ledger.balance, equals(0));
      expect(ledger.events, isEmpty);
      expect(ledger.id, equals('xp:member-001'));
      expect(ledger.memberId, equals('member-001'));
      expect(ledger.crdtVersion, equals(1));
    });
  });

  group('XpLedger.applyEvent', () {
    test('adds positive delta to balance', () {
      final ledger = XpLedger.empty('m1').applyEvent(
        XpEvent(taskId: 'task:a', delta: 50, at: DateTime.now().toUtc()),
      );
      expect(ledger.balance, equals(50));
      expect(ledger.events, hasLength(1));
    });

    test('subtracts negative delta (redemption)', () {
      final base = XpLedger.empty('m1').applyEvent(
        XpEvent(taskId: 'task:a', delta: 100, at: DateTime.now().toUtc()),
      );
      final after = base.applyEvent(
        XpEvent(taskId: 'redeem:1', delta: -30, at: DateTime.now().toUtc()),
      );
      expect(after.balance, equals(70));
    });

    test('accumulates multiple events correctly', () {
      var ledger = XpLedger.empty('m1');
      final deltas = [10, 20, 5, 15];
      for (final d in deltas) {
        ledger = ledger.applyEvent(
          XpEvent(taskId: 'task:$d', delta: d, at: DateTime.now().toUtc()),
        );
      }
      expect(ledger.balance, equals(50));
      expect(ledger.events, hasLength(4));
    });

    test('each applyEvent bumps crdtVersion by 1', () {
      final l1 = XpLedger.empty('m1');
      final l2 = l1.applyEvent(
        XpEvent(taskId: 'task:a', delta: 10, at: DateTime.now().toUtc()),
      );
      final l3 = l2.applyEvent(
        XpEvent(taskId: 'task:b', delta: 5, at: DateTime.now().toUtc()),
      );
      expect(l2.crdtVersion, equals(l1.crdtVersion + 1));
      expect(l3.crdtVersion, equals(l2.crdtVersion + 1));
    });

    test('original ledger is not mutated', () {
      final original = XpLedger.empty('m1');
      original.applyEvent(
        XpEvent(taskId: 'task:a', delta: 99, at: DateTime.now().toUtc()),
      );
      expect(original.balance, equals(0));
      expect(original.events, isEmpty);
    });
  });

  group('XpLedger JSON', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final ledger = XpLedger.empty('m1')
          .applyEvent(
            XpEvent(taskId: 'task:a', delta: 50, at: DateTime.now().toUtc()),
          )
          .applyEvent(
            XpEvent(taskId: 'task:b', delta: 25, at: DateTime.now().toUtc()),
          );

      final restored = XpLedger.fromJson(ledger.toJson());
      expect(restored.id, equals(ledger.id));
      expect(restored.memberId, equals(ledger.memberId));
      expect(restored.balance, equals(ledger.balance));
      expect(restored.events, hasLength(2));
      expect(restored.crdtVersion, equals(ledger.crdtVersion));
    });

    test('fromJson handles _id key (CouchDB format)', () {
      final json = {
        '_id': 'xp:member-42',
        'memberId': 'member-42',
        'balance': 100,
        'events': [],
        'crdtVersion': 3,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      final ledger = XpLedger.fromJson(json);
      expect(ledger.id, equals('xp:member-42'));
      expect(ledger.balance, equals(100));
    });
  });
}
