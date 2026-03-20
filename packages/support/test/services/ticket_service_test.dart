import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_support/kinetic_support.dart';

void main() {
  late InMemoryDocumentStore store;
  late TicketService sut;

  setUp(() {
    store = InMemoryDocumentStore();
    sut = TicketService(store: store);
  });

  // -------------------------------------------------------------------------
  // createTicket
  // -------------------------------------------------------------------------

  group('TicketService.createTicket', () {
    test('returns a ticket with status open and correct fields', () {
      final ticket = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'I need help with my task',
      );

      expect(ticket.status, equals(TicketStatus.open));
      expect(ticket.requesterId, equals('child-001'));
      expect(ticket.title, equals('I need help with my task'));
    });

    test('persists ticket to store', () {
      final ticket = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'Help',
      );

      expect(store.all.any((d) => d['_id'] == ticket.id), isTrue);
    });

    test('stores optional taskId', () {
      final ticket = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-001',
        title: 'Stuck',
        taskId: 'task:abc',
      );

      expect(ticket.taskId, equals('task:abc'));
    });
  });

  // -------------------------------------------------------------------------
  // openTickets query
  // -------------------------------------------------------------------------

  group('TicketService.openTickets', () {
    test('returns open and inProgress tickets', () {
      sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Open',
      );

      final ip = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'In Progress',
      );
      sut.updateStatus(ip.id, status: TicketStatus.inProgress);

      final resolved = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Resolved',
      );
      sut.updateStatus(resolved.id, status: TicketStatus.resolved);

      expect(sut.openTickets, hasLength(2));
    });

    test('excludes resolved and closed tickets', () {
      final t1 = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Resolved',
      );
      sut.updateStatus(t1.id, status: TicketStatus.resolved);

      final t2 = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Closed',
      );
      sut.updateStatus(t2.id, status: TicketStatus.closed);

      expect(sut.openTickets, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // ticketsForMember
  // -------------------------------------------------------------------------

  group('TicketService.ticketsForMember', () {
    test('filters tickets by requesterId', () {
      sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-A',
        title: 'A1',
      );
      sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-A',
        title: 'A2',
      );
      sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'child-B',
        title: 'B1',
      );

      final aTickets = sut.ticketsForMember('child-A');
      expect(aTickets, hasLength(2));
      expect(aTickets.every((t) => t.requesterId == 'child-A'), isTrue);
    });

    test('returns empty list when member has no tickets', () {
      expect(sut.ticketsForMember('nobody'), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // updateStatus
  // -------------------------------------------------------------------------

  group('TicketService.updateStatus', () {
    test('changes status and bumps crdtVersion', () {
      final ticket = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Help',
      );

      final updated = sut.updateStatus(
        ticket.id,
        status: TicketStatus.inProgress,
      );

      expect(updated.status, equals(TicketStatus.inProgress));
      expect(updated.crdtVersion, equals(ticket.crdtVersion + 1));
    });

    test('records resolvedById and resolution', () {
      final ticket = sut.createTicket(
        familyPlanId: 'plan:1',
        requesterId: 'c1',
        title: 'Help',
      );

      final resolved = sut.updateStatus(
        ticket.id,
        status: TicketStatus.resolved,
        resolvedById: 'parent-001',
        resolution: 'Showed them how to do it.',
      );

      expect(resolved.resolvedById, equals('parent-001'));
      expect(resolved.resolution, equals('Showed them how to do it.'));
    });

    test('throws StateError when ticket id is not found', () {
      expect(
        () => sut.updateStatus(
          'ticket:nonexistent',
          status: TicketStatus.resolved,
        ),
        throwsStateError,
      );
    });
  });
}
