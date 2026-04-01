import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../models/kids_task.dart';
import '../services/kids_task_repository.dart';
import 'kids_task_detail_screen.dart';

class KidsHomeScreen extends StatefulWidget {
  final AppDatabase appDb;

  const KidsHomeScreen({super.key, required this.appDb});

  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen>
    with WidgetsBindingObserver {
  late KidsTaskRepository _taskRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskRepository = KidsTaskRepository(db: widget.appDb);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _sync();
    }
  }

  void _sync() {
    // TODO: Implement sync when WebDAV config is available
    // For now, just refresh the UI
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Opdrachten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _sync,
            tooltip: 'Vernieuwen',
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
            return Center(child: Text('Fout: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Alles klaar!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Geen opdrachten op dit moment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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
              if (pendingTasks.isNotEmpty) ...[
                Text(
                  'Nog te doen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...pendingTasks.map((task) => _buildTaskCard(context, task)),
                const SizedBox(height: 24),
              ],
              if (completedTasks.isNotEmpty) ...[
                Text(
                  'Afgerond',
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
                      _priorityLabel(task.priority),
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
                      _formatDueDate(task.dueDate!),
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

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'Hoog',
      TaskPriority.normal => 'Normaal',
      TaskPriority.low => 'Laag',
    };
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(date.year, date.month, date.day);

    if (dueDay == today) {
      return 'Vandaag';
    } else if (dueDay == tomorrow) {
      return 'Morgen';
    } else if (dueDay.isBefore(today)) {
      return 'Verlopen';
    } else {
      return '${dueDay.day}/${dueDay.month}';
    }
  }
}
