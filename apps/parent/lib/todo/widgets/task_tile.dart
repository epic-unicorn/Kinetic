import 'package:flutter/material.dart';

import '../../partner/services/load_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/mission_converter_service.dart';
import '../../todo/services/todo_repository.dart';
import 'convert_to_mission_sheet.dart';
import 'task_detail_sheet.dart';

// ---------------------------------------------------------------------------
// TaskTile — a single personal task row.
//
// Swipe right  → complete / uncomplete
// Swipe left   → delete (with confirmation snackbar + undo)
// Tap          → open TaskDetailSheet
// Long-press   → context menu (flag, private, move list)
// ---------------------------------------------------------------------------

class TaskTile extends StatelessWidget {
  final PersonalTask task;
  final TodoRepository repo;
  final MissionConverterService? converter;
  final LoadSyncService? syncService;

  const TaskTile({
    super.key,
    required this.task,
    required this.repo,
    this.converter,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      // ── Swipe right: toggle complete ──────────────────────────────────────
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.green.shade700,
        icon: task.isCompleted ? Icons.undo : Icons.check,
      ),
      // ── Swipe left: delete ────────────────────────────────────────────────
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red.shade700,
        icon: Icons.delete_outline,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Toggle complete — don't actually dismiss the tile
          if (task.isCompleted) {
            await repo.uncompleteTask(task.id);
          } else {
            await repo.completeTask(task.id);
          }
          return false;
        }
        // Swipe-to-delete — let it dismiss, then show undo
        return true;
      },
      onDismissed: (_) {
        repo.deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${task.title}" verwijderd'),
            action: SnackBarAction(
              label: 'Ongedaan maken',
              onPressed: () {
                // Re-create task with same data
                repo.createTask(
                  title: task.title,
                  listId: task.listId,
                  notes: task.notes,
                  priority: task.priority,
                  dueDate: task.dueDate,
                  isAllDay: task.isAllDay,
                  recurrenceRule: task.recurrenceRule,
                  isFlagged: task.isFlagged,
                  isPrivate: task.isPrivate,
                );
              },
            ),
          ),
        );
      },
      child: _TaskTileContent(
        task: task,
        repo: repo,
        converter: converter,
        syncService: syncService,
      ),
    );
  }
}

class _TaskTileContent extends StatelessWidget {
  final PersonalTask task;
  final TodoRepository repo;
  final MissionConverterService? converter;
  final LoadSyncService? syncService;

  const _TaskTileContent({
    required this.task,
    required this.repo,
    this.converter,
    this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final hasDate = task.dueDate != null;
    final overdue = hasDate && isOverdue(task.dueDate!) && !task.isCompleted;

    return InkWell(
      onTap: () => _openDetail(context),
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkbox ────────────────────────────────────────────────────
            GestureDetector(
              onTap: () => task.isCompleted
                  ? repo.uncompleteTask(task.id)
                  : repo.completeTask(task.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: task.isCompleted
                      ? null
                      : Border.all(
                          color: task.priority != TaskPriority.none
                              ? priorityColor(task.priority)
                              : kColorWarmGrey,
                          width: 2,
                        ),
                  color: task.isCompleted ? kColorTeal : Colors.transparent,
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (task.priority != TaskPriority.none
                          ? Center(
                              child: Text(
                                priorityLabel(task.priority),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: priorityColor(task.priority),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null),
              ),
            ),
            // ── Title + metadata ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: tt.bodyLarge?.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? kColorWarmGrey : kColorOffWhite,
                    ),
                  ),
                  if (hasDate || task.notes != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (hasDate)
                          Text(
                            formatDueDate(task.dueDate!, allDay: task.isAllDay),
                            style: tt.labelSmall?.copyWith(
                              color: overdue
                                  ? Colors.redAccent
                                  : kColorWarmGrey,
                            ),
                          ),
                        if (hasDate && task.notes != null)
                          const Text(
                            ' · ',
                            style: TextStyle(color: kColorWarmGrey),
                          ),
                        if (task.notes != null)
                          Expanded(
                            child: Text(
                              task.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                color: kColorWarmGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // ── Right icons ──────────────────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.isFlagged)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.flag, size: 16, color: kColorGold),
                  ),
                if (task.isPrivate)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: kColorWarmGrey,
                    ),
                  ),
                if (task.recurrenceRule != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.repeat, size: 14, color: kColorWarmGrey),
                  ),
                // ── Mission badge ──────────────────────────────────────────
                if (task.kidsTaskId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _MissionBadge(
                      onTap: () => _openMissionSheet(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          TaskDetailSheet(task: task, repo: repo, converter: converter),
    );
  }

  void _openMissionSheet(BuildContext context) {
    if (converter == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ConvertToMissionSheet(task: task, converter: converter!),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                task.isFlagged ? Icons.flag : Icons.flag_outlined,
                color: kColorGold,
              ),
              title: Text(task.isFlagged ? 'Markering verwijderen' : 'Markeer'),
              onTap: () {
                Navigator.pop(context);
                repo.toggleFlag(task.id, flagged: !task.isFlagged);
              },
            ),
            ListTile(
              leading: Icon(
                task.isPrivate ? Icons.lock_open_outlined : Icons.lock_outline,
                color: kColorWarmGrey,
              ),
              title: Text(task.isPrivate ? 'Deelbaar maken' : 'Privé maken'),
              onTap: () {
                Navigator.pop(context);
                repo.togglePrivate(task.id, isPrivate: !task.isPrivate);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text('Taak verwijderen'),
              onTap: () {
                Navigator.pop(context);
                repo.deleteTask(task.id);
              },
            ),
            if (syncService != null)
              ListTile(
                leading: const Icon(Icons.share_outlined, color: kColorTeal),
                title: const Text('Voorstel sturen naar partner'),
                onTap: () {
                  Navigator.pop(context);
                  _sendProposalToPartner(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _sendProposalToPartner(BuildContext context) {
    final partnerLoad = syncService?.partnerLoad;
    if (partnerLoad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner is niet beschikbaar'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    syncService!.sendProposal(toDeviceId: partnerLoad.deviceId, task: task);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" voorgesteld aan partner'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mission badge — shown when task.kidsTaskId != null.
// ---------------------------------------------------------------------------

class _MissionBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const _MissionBadge({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kColorGold.withAlpha(40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kColorGold.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 10, color: kColorGold),
            const SizedBox(width: 2),
            Text(
              'Opdracht',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: kColorGold, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }
}
