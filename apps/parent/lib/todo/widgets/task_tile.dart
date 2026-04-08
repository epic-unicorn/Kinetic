import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../partner/services/partner_proposal_repository.dart';
import '../../sync/webdav_config_repository.dart';
import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import 'category_sheet.dart';
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
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final WebDavConfigRepository? configRepo;

  const TaskTile({
    super.key,
    required this.task,
    required this.repo,
    this.hasFamilyKey = false,
    this.proposalRepo,
    this.myParentId,
    this.configRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.startToEnd,
      // ── Swipe right: toggle complete (or advance recurring task) ──────────
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.green.shade700,
        icon: task.isCompleted
            ? Icons.undo
            : (task.recurrenceRule != null ? Icons.repeat : Icons.check),
      ),
      confirmDismiss: (direction) async {
        // Toggle complete — don't actually dismiss the tile
        if (task.isCompleted) {
          await repo.uncompleteTask(task.id);
        } else {
          await repo.completeTask(task.id);
          await _playCompletionFeedback();
        }
        return false;
      },
      child: _TaskTileContent(
        task: task,
        repo: repo,
        hasFamilyKey: hasFamilyKey,
        proposalRepo: proposalRepo,
        myParentId: myParentId,
        configRepo: configRepo,
      ),
    );
  }
}

class _TaskTileContent extends StatefulWidget {
  final PersonalTask task;
  final TodoRepository repo;
  final bool hasFamilyKey;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final WebDavConfigRepository? configRepo;

  const _TaskTileContent({
    required this.task,
    required this.repo,
    this.hasFamilyKey = false,
    this.proposalRepo,
    this.myParentId,
    this.configRepo,
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
    final overdue =
        hasDate && isOverdue(widget.task.dueDate!) && !widget.task.isCompleted;

    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        onLongPress: () => _pickCategory(context),
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
                            width: widget.task.priority == TaskPriority.high
                                ? 2.5
                                : 2,
                          ),
                    color: widget.task.isCompleted
                        ? kColorTeal
                        : (widget.task.priority != TaskPriority.none
                              ? priorityColor(
                                  widget.task.priority,
                                ).withAlpha(30)
                              : Colors.transparent),
                    boxShadow:
                        widget.task.priority != TaskPriority.none &&
                            !widget.task.isCompleted
                        ? [
                            BoxShadow(
                              color: priorityColor(
                                widget.task.priority,
                              ).withAlpha(50),
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
                  // ── Accepted from partner proposal ─────────────────────────
                  if (widget.proposalRepo != null)
                    StreamBuilder<bool>(
                      stream: widget.proposalRepo!
                          .watchAcceptedProposalForTask(
                            taskTitle: widget.task.title,
                          ),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.person_add_outlined,
                              size: 14,
                              color: kColorTeal,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  // ── Outgoing proposal status ───────────────────────────────
                  if (widget.proposalRepo != null &&
                      widget.myParentId != null &&
                      widget.myParentId!.isNotEmpty)
                    StreamBuilder<ProposalStatus?>(
                      stream: widget.proposalRepo!.watchOutgoingProposalStatus(
                        taskTitle: widget.task.title,
                        fromParentId: widget.myParentId!,
                      ),
                      builder: (context, snapshot) {
                        final status = snapshot.data;
                        if (status == ProposalStatus.pending ||
                            status == ProposalStatus.snoozed) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.people_outline,
                              size: 14,
                              color: kColorTeal,
                            ),
                          );
                        }
                        if (status == ProposalStatus.rejected ||
                            status == ProposalStatus.dismissed) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.person_off_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
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
      builder: (_) => TaskDetailSheet(
        task: widget.task,
        repo: widget.repo,
        hasFamilyKey: widget.hasFamilyKey,
        proposalRepo: widget.proposalRepo,
        myParentId: widget.myParentId,
        configRepo: widget.configRepo,
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final categories = await widget.repo.watchTaskCategories().first;
    if (!mounted) return;
    final result = await showCategoryPicker(
      // ignore: use_build_context_synchronously
      context: context,
      existingCategories: categories,
      currentCategory: widget.task.customCategory,
    );
    if (result != null) {
      await widget.repo.updateTaskCustomCategory(
        widget.task.id,
        result.isEmpty ? null : result,
      );
    }
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
