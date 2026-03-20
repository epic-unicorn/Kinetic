import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_support/kinetic_support.dart';

void main() {
  group('SupportTicket.create', () {
    test('generates a unique id prefixed with "ticket:"', () {
      final t1 = SupportTicket.create(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'I need help',
      );
      final t2 = SupportTicket.create(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'I need help',
      );
      expect(t1.id, startsWith('ticket:'));
      expect(t2.id, startsWith('ticket:'));
      expect(t1.id, isNot(equals(t2.id)));
    });

    test('sets status to open and crdtVersion to 1', () {
      final ticket = SupportTicket.create(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'Help!',
      );
      expect(ticket.status, equals(TicketStatus.open));
      expect(ticket.crdtVersion, equals(1));
    });

    test('stores optional taskId and description', () {
      final ticket = SupportTicket.create(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'Stuck on task',
        taskId: 'task:abc',
        description: 'I do not understand the instructions.',
      );
      expect(ticket.taskId, equals('task:abc'));
      expect(
        ticket.description,
        equals('I do not understand the instructions.'),
      );
    });
  });

  group('SupportTicket.copyWith', () {
    late SupportTicket base;

    setUp(() {
      base = SupportTicket.create(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'Help me',
      );
    });

    test('bumps crdtVersion by exactly 1', () {
      final updated = base.copyWith(status: TicketStatus.inProgress);
      expect(updated.crdtVersion, equals(base.crdtVersion + 1));
    });

    test('changes status without mutating other fields', () {
      final updated = base.copyWith(status: TicketStatus.inProgress);
      expect(updated.status, equals(TicketStatus.inProgress));
      expect(updated.id, equals(base.id));
      expect(updated.requesterId, equals(base.requesterId));
    });

    test('records resolvedById and resolution when resolved', () {
      final resolved = base.copyWith(
        status: TicketStatus.resolved,
        resolvedById: 'parent-999',
        resolution: 'Explained the task',
      );
      expect(resolved.status, equals(TicketStatus.resolved));
      expect(resolved.resolvedById, equals('parent-999'));
      expect(resolved.resolution, equals('Explained the task'));
    });
  });

  group('SupportTicket JSON', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final original = SupportTicket.create(
        familyPlanId: 'plan:42',
        requesterId: 'child-007',
        title: 'Please help',
        taskId: 'task:xyz',
        description: 'Confusing step.',
      );
      final restored = SupportTicket.fromJson(original.toJson());

      expect(restored.id, equals(original.id));
      expect(restored.familyPlanId, equals(original.familyPlanId));
      expect(restored.requesterId, equals(original.requesterId));
      expect(restored.taskId, equals(original.taskId));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.status, equals(original.status));
      expect(restored.crdtVersion, equals(original.crdtVersion));
    });

    test('fromJson uses _id key (CouchDB format)', () {
      final json = {
        '_id': 'ticket:test-123',
        'familyPlanId': 'plan:1',
        'requesterId': 'child-001',
        'title': 'Test',
        'status': 'open',
        'crdtVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      final ticket = SupportTicket.fromJson(json);
      expect(ticket.id, equals('ticket:test-123'));
    });
  });
}
