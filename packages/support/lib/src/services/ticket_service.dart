import '../models/support_ticket.dart';
import '../store/document_store.dart';

/// CRUD service for [SupportTicket] documents.
///
/// Tickets are keyed in the [DocumentStore] by their `_id` field, which begins
/// with `ticket:` — that prefix is used to distinguish them from Task, Plan,
/// and XpLedger documents in the shared flat store.
class TicketService {
  final DocumentStore _store;

  TicketService({required DocumentStore store}) : _store = store;

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Creates a new [SupportTicket] and persists it to [_store].
  SupportTicket createTicket({
    required String familyPlanId,
    required String requesterId,
    required String title,
    String? taskId,
    String? description,
  }) {
    final ticket = SupportTicket.create(
      familyPlanId: familyPlanId,
      requesterId: requesterId,
      title: title,
      taskId: taskId,
      description: description,
    );
    _store.upsert(ticket.toJson());
    return ticket;
  }

  /// Updates the status of an existing ticket identified by [ticketId].
  ///
  /// Throws [StateError] if no ticket with that id is found.
  SupportTicket updateStatus(
    String ticketId, {
    required TicketStatus status,
    String? resolvedById,
    String? resolution,
  }) {
    final doc = _store.all
        .where((d) => d['_id'] == ticketId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    if (doc == null) throw StateError('Ticket "$ticketId" not found.');

    final updated = SupportTicket.fromJson(doc).copyWith(
      status: status,
      resolvedById: resolvedById,
      resolution: resolution,
    );
    _store.upsert(updated.toJson());
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// All tickets currently in [TicketStatus.open] or [TicketStatus.inProgress].
  List<SupportTicket> get openTickets => _allTickets
      .where(
        (t) =>
            t.status == TicketStatus.open ||
            t.status == TicketStatus.inProgress,
      )
      .toList();

  /// All tickets raised by [memberId].
  List<SupportTicket> ticketsForMember(String memberId) =>
      _allTickets.where((t) => t.requesterId == memberId).toList();

  /// All tickets, regardless of status.
  List<SupportTicket> get allTickets => _allTickets;

  List<SupportTicket> get _allTickets => _store.all
      .where((d) => (d['_id'] as String?)?.startsWith('ticket:') ?? false)
      .map((d) => SupportTicket.fromJson(d))
      .toList();
}
