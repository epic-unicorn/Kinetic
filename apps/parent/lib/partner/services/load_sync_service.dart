import 'package:kinetic_core/kinetic_core.dart' show IdentityService;

import '../../support/couch_document_store.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import '../models/load_snapshot.dart';

// ---------------------------------------------------------------------------
// LoadSyncService
//
// Publishes this parent's LoadSnapshot to the shared CouchDB store so the
// partner's device can see the aggregate load.  Also reads back the partner's
// snapshot and imports any incoming partner_proposal documents into the local
// TodoRepository.
//
// C3 privacy model: only category scores are published — no task titles.
// ---------------------------------------------------------------------------

class LoadSyncService {
  final CouchDocumentStore _store;
  String? _myDeviceId;

  LoadSyncService({
    required CouchDocumentStore store,
    required IdentityService identityService,
  }) : _store = store {
    identityService.getOrCreateIdentity().then(
      (id) => _myDeviceId = id.deviceId,
    );
  }

  // ── Outbound ──────────────────────────────────────────────────────────────

  /// Upserts this parent's load snapshot into the shared store.
  /// No-op until the device identity has been resolved.
  void publishMyLoad(LoadSnapshot snapshot) {
    final id = _myDeviceId;
    if (id == null) return;
    _store.upsert(
      ParentLoadDoc(
        deviceId: id,
        snapshot: snapshot,
        updatedAt: DateTime.now().toUtc(),
      ).toJson(),
    );
  }

  /// Writes an anonymous proposal to the shared store.
  /// The partner's device will import it on the next sync.
  ///
  /// C3 privacy: only category + priority are shared, not the task title.
  void sendProposal({required String toDeviceId, required PersonalTask task}) {
    final id = _myDeviceId;
    if (id == null) return;
    _store.upsert({
      '_id': 'partner_proposal_${task.id}',
      'type': 'partner_proposal',
      'fromDeviceId': id,
      'toDeviceId': toDeviceId,
      'taskId': task.id,
      // Only share category label — never the real title.
      'taskTitle': 'A ${_categoryLabel(task.category)} task',
      'taskCategory': task.category.name,
      'taskPriority': task.priority.index,
      'taskDueDate': task.dueDate?.toIso8601String(),
      'sentAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Writes a shared-task doc so both partners can see an accepted proposal.
  /// Call this when the receiving partner accepts a proposal.
  void acceptProposal(PartnerProposal proposal) {
    final id = _myDeviceId;
    if (id == null) return;
    _store.upsert({
      '_id': 'shared_task_${proposal.id}',
      'type': 'shared_task',
      'fromDeviceId': proposal.fromParentId,
      'acceptedByDeviceId': id,
      'taskTitle': proposal.taskTitle,
      'taskCategory': proposal.taskCategory.name,
      'taskPriority': proposal.taskPriority.index,
      'taskDueDate': proposal.taskDueDate?.toIso8601String(),
      'acceptedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ── Inbound ───────────────────────────────────────────────────────────────

  /// Returns the partner's most recent load snapshot, or null if unavailable.
  ParentLoadDoc? get partnerLoad {
    final id = _myDeviceId;
    ParentLoadDoc? latest;
    for (final doc in _store.all) {
      if (doc['type'] != ParentLoadDoc.docType) continue;
      // Skip our own document.
      if (id != null && doc['deviceId'] == id) continue;
      final parsed = ParentLoadDoc.fromJson(doc);
      if (parsed == null) continue;
      if (latest == null || parsed.updatedAt.isAfter(latest.updatedAt)) {
        latest = parsed;
      }
    }
    return latest;
  }

  /// Returns all shared-task docs involving this device (sender or acceptor),
  /// sorted newest first.
  List<SharedTask> get sharedTasks {
    final id = _myDeviceId;
    final results = <SharedTask>[];
    for (final doc in _store.all) {
      if (doc['type'] != 'shared_task') continue;
      if (id != null &&
          doc['fromDeviceId'] != id &&
          doc['acceptedByDeviceId'] != id) {
        continue;
      }
      final task = SharedTask._fromJson(doc);
      if (task != null) results.add(task);
    }
    results.sort((a, b) => b.acceptedAt.compareTo(a.acceptedAt));
    return results;
  }

  /// Imports pending partner_proposal docs addressed to this device into the
  /// local [TodoRepository].  Call this on every sync status change.
  Future<void> syncIncomingProposals(TodoRepository repo) async {
    final id = _myDeviceId;
    if (id == null) return;
    for (final doc in _store.all) {
      if (doc['type'] != 'partner_proposal') continue;
      if (doc['toDeviceId'] != id) continue;
      final proposal = _parseProposal(doc);
      if (proposal == null) continue;
      await repo.saveProposal(proposal);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  PartnerProposal? _parseProposal(Map<String, dynamic> doc) {
    try {
      return PartnerProposal(
        id: doc['_id'] as String,
        fromParentId: doc['fromDeviceId'] as String,
        taskTitle: doc['taskTitle'] as String,
        taskNotes: null,
        taskCategory: TaskCategory.values.byName(
          (doc['taskCategory'] as String?) ?? 'other',
        ),
        taskPriority: TaskPriority.values[(doc['taskPriority'] as int?) ?? 0],
        taskDueDate: doc['taskDueDate'] != null
            ? DateTime.parse(doc['taskDueDate'] as String)
            : null,
        status: ProposalStatus.pending,
        receivedAt: DateTime.parse(doc['sentAt'] as String),
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  String _categoryLabel(TaskCategory c) => switch (c) {
    TaskCategory.household => 'household',
    TaskCategory.health => 'health',
    TaskCategory.admin => 'admin',
    TaskCategory.school => 'school',
    TaskCategory.finance => 'finance',
    TaskCategory.other => '',
  };
}

// ---------------------------------------------------------------------------
// SharedTask — a proposal that was accepted by the receiving partner.
// Both the sender and the acceptor can see this doc via CouchDB sync.
// ---------------------------------------------------------------------------

class SharedTask {
  final String id;
  final String fromDeviceId;
  final String acceptedByDeviceId;
  final String taskTitle;
  final TaskCategory taskCategory;
  final TaskPriority taskPriority;
  final DateTime? taskDueDate;
  final DateTime acceptedAt;

  const SharedTask({
    required this.id,
    required this.fromDeviceId,
    required this.acceptedByDeviceId,
    required this.taskTitle,
    required this.taskCategory,
    required this.taskPriority,
    required this.taskDueDate,
    required this.acceptedAt,
  });

  static SharedTask? _fromJson(Map<String, dynamic> doc) {
    try {
      return SharedTask(
        id: doc['_id'] as String,
        fromDeviceId: doc['fromDeviceId'] as String,
        acceptedByDeviceId: doc['acceptedByDeviceId'] as String,
        taskTitle: doc['taskTitle'] as String,
        taskCategory: TaskCategory.values.byName(
          (doc['taskCategory'] as String?) ?? 'other',
        ),
        taskPriority: TaskPriority.values[(doc['taskPriority'] as int?) ?? 0],
        taskDueDate: doc['taskDueDate'] != null
            ? DateTime.parse(doc['taskDueDate'] as String)
            : null,
        acceptedAt: DateTime.parse(doc['acceptedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
