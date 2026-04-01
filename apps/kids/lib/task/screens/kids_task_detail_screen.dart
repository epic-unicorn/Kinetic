import 'package:flutter/material.dart';

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
    return StreamBuilder<KidsTask?>(
      stream: widget.repository.watchOne(widget.taskId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Laden...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Fout')),
            body: Center(child: Text('Taak niet gevonden: ${snapshot.error}')),
          );
        }

        final task = snapshot.data!;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Taakdetails'),
          ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: scheme.onSurface,
                                    ),
                              ),
                              if (task.isCompleted)
                                Text(
                                  'Afgerond',
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
                  'Gegevens',
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
                              'Vervaldatum',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (task.dueDate != null)
                              Text(
                                _formatFullDate(task.dueDate!),
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            else
                              Text(
                                'Geen vervaldatum',
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
                              'Prioriteit',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _priorityLabel(task.priority),
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
                              'Categorie',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              _categoryLabel(task.category),
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
                              'Ervaring',
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
                    'Opmerkingen',
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
                    label: const Text('Verwijderen'),
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

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => 'Urgent',
      TaskPriority.high => 'Hoog',
      TaskPriority.normal => 'Normaal',
      TaskPriority.low => 'Laag',
    };
  }

  String _categoryLabel(TaskCategory category) {
    return switch (category) {
      TaskCategory.household => 'Huishouden',
      TaskCategory.school => 'School',
      TaskCategory.health => 'Gezondheid',
      TaskCategory.shopping => 'Boodschappen',
      TaskCategory.entertainment => 'Recreatie',
      TaskCategory.other => 'Overig',
    };
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'januari',
      'februari',
      'maart',
      'april',
      'mei',
      'juni',
      'juli',
      'augustus',
      'september',
      'oktober',
      'november',
      'december',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
