import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import 'task_detail_sheet.dart';

// ---------------------------------------------------------------------------
// Helper: Task completion feedback (haptic + notification sound)
// ---------------------------------------------------------------------------

const _channel = MethodChannel('net.moonbaseone.kinetic.parent/audio');

Future<void> _playCompletionFeedback() async {
  // Haptic feedback
  HapticFeedback.mediumImpact();

  // Audio feedback — play system notification sound
  try {
    await _channel.invokeMethod('playNotificationSound');
  } catch (e) {
    // Silently fail if sound doesn't play
  }
}

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
  final bool hasFamilyKey;

  const TaskTile({
    super.key,
    required this.task,
    required this.repo,
    this.hasFamilyKey = false,
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
            await _playCompletionFeedback();
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
        hasFamilyKey: hasFamilyKey,
      ),
    );
  }
}

class _TaskTileContent extends StatefulWidget {
  final PersonalTask task;
  final TodoRepository repo;
  final bool hasFamilyKey;

  const _TaskTileContent({
    required this.task,
    required this.repo,
    this.hasFamilyKey = false,
  });

  @override
  State<_TaskTileContent> createState() => _TaskTileContentState();
}

class _TaskTileContentState extends State<_TaskTileContent> {
  Future<void> _toggleComplete() async {
    if (widget.task.isCompleted) {
      await widget.repo.uncompleteTask(widget.task.id);
    } else {
      await widget.repo.completeTask(widget.task.id);
      await _playCompletionFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final hasDate = widget.task.dueDate != null;
    final overdue = hasDate && isOverdue(widget.task.dueDate!) && !widget.task.isCompleted;

    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        onLongPress: () => _showContextMenu(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Checkbox ────────────────────────────────────────────────────
              GestureDetector(
                onTap: _toggleComplete,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 1, right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: widget.task.isCompleted
                        ? null
                        : Border.all(
                            color: widget.task.priority != TaskPriority.none
                                ? priorityColor(widget.task.priority)
                                : kColorWarmGrey,
                            width: widget.task.priority == TaskPriority.high ? 2.5 : 2,
                          ),
                    color: widget.task.isCompleted
                        ? kColorTeal
                        : (widget.task.priority != TaskPriority.none
                              ? priorityColor(widget.task.priority).withAlpha(30)
                              : Colors.transparent),
                    boxShadow:
                        widget.task.priority != TaskPriority.none && !widget.task.isCompleted
                        ? [
                            BoxShadow(
                              color: priorityColor(widget.task.priority).withAlpha(50),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.task.isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              // ── Title + metadata ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: tt.bodyLarge?.copyWith(
                        decoration: widget.task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: widget.task.isCompleted
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (hasDate || widget.task.notes != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (hasDate)
                            Text(
                              formatDueDate(
                                widget.task.dueDate!,
                                allDay: widget.task.isAllDay,
                              ),
                              style: tt.labelSmall?.copyWith(
                                color: overdue
                                    ? Colors.redAccent
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (hasDate && widget.task.notes != null)
                            Text(
                              ' · ',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (widget.task.notes != null)
                            Expanded(
                              child: Text(
                                widget.task.notes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelSmall?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                  if (widget.task.isFlagged)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.flag, size: 16, color: kColorGold),
                    ),
                  if (widget.task.isPrivate)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: kColorWarmGrey,
                      ),
                    ),
                  if (widget.task.recurrenceRule != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.repeat,
                        size: 14,
                        color: kColorWarmGrey,
                      ),
                    ),
                  // ── Mission badge ──────────────────────────────────────
                  if (widget.task.kidsTaskId != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: _MissionBadge(),
                    ),
                ],
              ),
            ],
          ),
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
          TaskDetailSheet(task: widget.task, repo: widget.repo, hasFamilyKey: widget.hasFamilyKey),
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
                widget.task.isFlagged ? Icons.flag : Icons.flag_outlined,
                color: kColorGold,
              ),
              title: Text(widget.task.isFlagged ? 'Markering verwijderen' : 'Markeer'),
              onTap: () {
                Navigator.pop(context);
                widget.repo.toggleFlag(widget.task.id, flagged: !widget.task.isFlagged);
              },
            ),
            ListTile(
              leading: Icon(
                widget.task.isPrivate ? Icons.lock_open_outlined : Icons.lock_outline,
                color: kColorWarmGrey,
              ),
              title: Text(widget.task.isPrivate ? 'Deelbaar maken' : 'Privé maken'),
              onTap: () {
                Navigator.pop(context);
                widget.repo.togglePrivate(widget.task.id, isPrivate: !widget.task.isPrivate);
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
                widget.repo.deleteTask(widget.task.id);
              },
            ),
            // Greyed-out placeholder — only shown when connected to a family.
            if (widget.hasFamilyKey)
              ListTile(
                leading: const Icon(Icons.send_outlined, color: Colors.white24),
                title: const Text(
                  'Stuur naar kinderen',
                  style: TextStyle(color: Colors.white24),
                ),
                subtitle: const Text(
                  'Binnenkort beschikbaar',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mission badge — shown when task.kidsTaskId != null.
// ---------------------------------------------------------------------------

class _MissionBadge extends StatelessWidget {
  const _MissionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
