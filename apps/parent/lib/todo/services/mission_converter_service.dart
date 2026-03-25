import 'package:kinetic_core/kinetic_core.dart'
    show FamilyPlan, IdentityService, Task, TaskCategory;
import 'package:kinetic_support/kinetic_support.dart' show NotificationService;

import '../../support/couch_document_store.dart';
import '../models/personal_task.dart';
import '../services/todo_repository.dart';

// ---------------------------------------------------------------------------
// MissionConverterService
//
// Converts a PersonalTask into a kids Task (kinetic_core) and writes the
// resulting task ID back onto the PersonalTask as a backlink.
//
// Persistence: the kids Task is upserted into the shared CouchDocumentStore
// so it syncs to child devices automatically on the next heartbeat.
//
// familyPlanId: read from the local store (a 'family_plan' doc), falling
// back to the parent's deviceId if the plan hasn't been synced yet.
// ---------------------------------------------------------------------------

class MissionConverterService {
  final CouchDocumentStore _store;
  final TodoRepository _repo;
  final IdentityService _identityService;
  final NotificationService? _notifications;

  MissionConverterService({
    required CouchDocumentStore store,
    required TodoRepository repo,
    required IdentityService identityService,
    NotificationService? notifications,
  }) : _store = store,
       _repo = repo,
       _identityService = identityService,
       _notifications = notifications;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Converts [personalTask] into a kids mission.
  ///
  /// [xpReward]        — XP awarded on completion (1–100).
  /// [assignToChildId] — optional FamilyMember.id to pre-assign the mission.
  /// [dueDate]         — optional deadline; also schedules a no-response
  ///                     notification one day after the deadline.
  ///
  /// Returns the created [Task].
  Future<Task> convertToMission(
    PersonalTask personalTask, {
    required int xpReward,
    String? assignToChildId,
    DateTime? dueDate,
  }) async {
    final identity = await _identityService.getOrCreateIdentity();
    final familyPlanId = _resolveFamilyPlanId(identity.deviceId);

    final mission = Task.create(
      familyPlanId: familyPlanId,
      createdById: identity.deviceId,
      title: personalTask.title,
      description: personalTask.notes,
      category: TaskCategory.mission,
      xpReward: xpReward,
      assignedToId: assignToChildId,
      dueDate: dueDate,
    );

    // Persist in shared store (syncs to child devices).
    _store.upsert({'_id': mission.id, ...mission.toJson()});

    // Store backlink on the personal task.
    await _repo.updateTask(personalTask.copyWith(kidsTaskId: mission.id));

    // Schedule a no-response reminder one day after the deadline.
    final notif = _notifications;
    if (dueDate != null && notif != null) {
      final notifyAt = dueDate.add(const Duration(days: 1));
      await notif.scheduleReminder(
        id: mission.id.hashCode.abs(),
        title: 'Geen reactie op opdracht',
        body:
            '"${personalTask.title}" is verlopen — kind heeft niet gereageerd.',
        at: notifyAt,
      );
    }

    return mission;
  }

  /// Returns children listed in the family plan doc, or empty if not yet synced.
  List<({String id, String name})> get availableChildren {
    for (final doc in _store.all) {
      if (doc['type'] != 'family_plan') continue;
      try {
        final plan = FamilyPlan.fromJson(doc);
        return plan.children.map((m) => (id: m.id, name: m.name)).toList();
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _resolveFamilyPlanId(String fallbackDeviceId) {
    for (final doc in _store.all) {
      if (doc['type'] == 'family_plan') {
        final id = doc['id'] as String?;
        if (id != null && id.isNotEmpty) return id;
      }
    }
    // No plan synced yet — use device ID as a stable placeholder.
    return fallbackDeviceId;
  }
}
