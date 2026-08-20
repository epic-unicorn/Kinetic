import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/kids_task.dart';
import '../services/kids_task_repository.dart';

class KidsTaskDetailScreen extends StatefulWidget {
  final KidsTaskRepository repository;
  final String taskId;

  const KidsTaskDetailScreen({
    super.key,
    required this.repository,
    required this.taskId,
  });

  @override
  State<KidsTaskDetailScreen> createState() => _KidsTaskDetailScreenState();
}

class _KidsTaskDetailScreenState extends State<KidsTaskDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<KidsTask?>(
      stream: widget.repository.watchOne(widget.taskId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.error)),
            body: Center(
              child: Text(l10n.taskNotFound(snapshot.error ?? '')),
            ),
          );
        }

        final task = snapshot.data!;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.taskDetails)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) {
                            if (value ?? false) {
                              widget.repository.markComplete(task.id);
                            } else {
                              widget.repository.markIncomplete(task.id);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: scheme.onSurface,
                                    ),
                              ),
                              if (task.isCompleted)
                                Text(
                                  l10n.completed,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Details section
                Text(
                  l10n.details,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Due date
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: scheme.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dueDate,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (task.dueDate != null)
                              Text(
                                _formatFullDate(context, task.dueDate!),
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            else
                              Text(
                                l10n.noDueDate,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Priority
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag,
                          color: _getPriorityColor(scheme, task.priority),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.priority,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _priorityLabel(l10n, task.priority),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.sell, color: scheme.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.category,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _categoryLabel(l10n, task.category),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // XP
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: scheme.primaryContainer),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.experience,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              '${task.xpReward} XP',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Notes section
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  Text(
                    l10n.notes,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        task.notes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.repository.delete(task.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete),
                    label: Text(l10n.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  String _categoryLabel(AppLocalizations l10n, TaskCategory category) {
    return switch (category) {
      TaskCategory.household => l10n.categoryHousehold,
      TaskCategory.school => l10n.categorySchool,
      TaskCategory.health => l10n.categoryHealth,
      TaskCategory.shopping => l10n.categoryShopping,
      TaskCategory.entertainment => l10n.categoryEntertainment,
      TaskCategory.other => l10n.categoryOther,
    };
  }

  String _formatFullDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMMd(locale).format(date);
  }
}
