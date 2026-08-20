import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_orchestrator.dart';
import '../../theme/app_header.dart';
import '../models/kids_task.dart';
import '../services/kids_task_repository.dart';
import 'kids_task_detail_screen.dart';

class KidsHomeScreen extends StatefulWidget {
  final AppDatabase appDb;
  final KidsTaskRepository? repository;
  final KidsSyncOrchestrator? orchestrator;
  final VoidCallback? onLeaveFamily;
  final DateTime? xpResetAt;

  const KidsHomeScreen({
    super.key,
    required this.appDb,
    this.repository,
    this.orchestrator,
    this.onLeaveFamily,
    this.xpResetAt,
  });

  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen> {
  late KidsTaskRepository _taskRepository;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _taskRepository = widget.repository ?? KidsTaskRepository(db: widget.appDb);
  }

  Future<void> _sync() async {
    if (_syncing || widget.orchestrator == null) return;
    setState(() => _syncing = true);
    try {
      await widget.orchestrator!.sync();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppHeaderKids(title: l10n.myTasks),
        actions: [
          if (widget.orchestrator != null) ...[
            if (_syncing)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: _sync,
                tooltip: l10n.sync,
              ),
          ],
          if (widget.onLeaveFamily != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'leave') widget.onLeaveFamily!();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.leaveFamily),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<KidsTask>>(
        stream: _taskRepository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorWithDetails(snapshot.error!)));
          }

          final tasks = snapshot.data ?? [];

          // XP header
          final xpHeader = StreamBuilder<int>(
            stream: _taskRepository.watchTotalXp(
              resetAt: widget.xpResetAt,
            ),
            builder: (context, xpSnap) {
              final totalXp = xpSnap.data ?? 0;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$totalXp XP',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          );

          if (tasks.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  xpHeader,
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.celebration, size: 64, color: scheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            l10n.allDone,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noTasksRightNow,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Group task by due date (today, tomorrow, later)
          final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
          final completedTasks = tasks.where((t) => t.isCompleted).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              xpHeader,
              if (pendingTasks.isNotEmpty) ...[
                Text(
                  l10n.stillToDo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...pendingTasks.map((task) => _buildTaskCard(context, task)),
                const SizedBox(height: 24),
              ],
              if (completedTasks.isNotEmpty) ...[
                Text(
                  l10n.completed,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...completedTasks.map((task) => _buildTaskCard(context, task)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, KidsTask task) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final priorityColor = _getPriorityColor(scheme, task.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) {
            if (value ?? false) {
              _taskRepository.markComplete(task.id);
            } else {
              _taskRepository.markIncomplete(task.id);
            }
          },
        ),
        title: Text(
          task.title,
          style: task.isCompleted
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: scheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.notes != null && task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.notes!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _priorityLabel(l10n, task.priority),
                      style: TextStyle(
                        fontSize: 11,
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Due date
                  if (task.dueDate != null)
                    Text(
                      _formatDueDate(l10n, task.dueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            '${task.xpReward} XP',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KidsTaskDetailScreen(
                repository: _taskRepository,
                taskId: task.id,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(ColorScheme scheme, TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => Colors.red,
      TaskPriority.high => Colors.deepOrange,
      TaskPriority.normal => Colors.orange,
      TaskPriority.low => Colors.green,
    };
  }

  String _priorityLabel(AppLocalizations l10n, TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => l10n.priorityUrgent,
      TaskPriority.high => l10n.priorityHigh,
      TaskPriority.normal => l10n.priorityNormal,
      TaskPriority.low => l10n.priorityLow,
    };
  }

  String _formatDueDate(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(date.year, date.month, date.day);

    if (dueDay == today) {
      return l10n.today;
    } else if (dueDay == tomorrow) {
      return l10n.tomorrow;
    } else if (dueDay.isBefore(today)) {
      return l10n.overdue;
    } else {
      return DateFormat.Md().format(dueDay);
    }
  }
}
