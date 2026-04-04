import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_header.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import '../../todo/widgets/quick_add_bar.dart';
import '../../todo/widgets/task_detail_sheet.dart';
import '../../todo/widgets/task_tile.dart';

// ---------------------------------------------------------------------------
// TasksScreen — tabbed view: open tasks + completed tasks.
// ---------------------------------------------------------------------------

class TasksScreen extends StatefulWidget {
  final TodoRepository repo;
  final ValueNotifier<SyncStatus>? syncStatus;
  final bool hasFamilyKey;
  final VoidCallback? onSyncRetry;

  const TasksScreen({
    super.key,
    required this.repo,
    this.syncStatus,
    this.hasFamilyKey = false,
    this.onSyncRetry,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppHeader(title: 'Taken', centerTitle: false),
        centerTitle: false,
        actions: [
          if (widget.syncStatus != null)
            ValueListenableBuilder<SyncStatus>(
              valueListenable: widget.syncStatus!,
              builder: (context, status, _) => _SyncIcon(
                status: status,
                onRetryPressed: widget.onSyncRetry,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => TaskDetailSheet(
                repo: widget.repo,
                hasFamilyKey: widget.hasFamilyKey,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Voltooid'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OpenTasksTab(repo: widget.repo, hasFamilyKey: widget.hasFamilyKey),
          _CompletedTasksTab(
            repo: widget.repo,
            hasFamilyKey: widget.hasFamilyKey,
          ),
        ],
      ),
      bottomSheet: QuickAddBar(repo: widget.repo),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync icon
// ---------------------------------------------------------------------------

class _SyncIcon extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onRetryPressed;

  const _SyncIcon({
    required this.status,
    this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: switch (status) {
        SyncStatus.syncing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SyncStatus.error => GestureDetector(
          onTap: onRetryPressed,
          child: Tooltip(
            message: 'Sync mislukt, tap om opnieuw te proberen.',
            child: Icon(
              Icons.sync_problem_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        SyncStatus.idle => const Icon(Icons.cloud_done_outlined),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Open tasks tab — grouped by customCategory with drag-to-reorder
// ---------------------------------------------------------------------------

// Sealed types for the flat list items used by ReorderableListView.
sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final String? category;
  _HeaderItem({required this.category});
}

class _TaskItem extends _ListItem {
  final PersonalTask task;
  _TaskItem({required this.task});
}

class _OpenTasksTab extends StatefulWidget {
  final TodoRepository repo;
  final bool hasFamilyKey;

  const _OpenTasksTab({required this.repo, this.hasFamilyKey = false});

  @override
  State<_OpenTasksTab> createState() => _OpenTasksTabState();
}

class _OpenTasksTabState extends State<_OpenTasksTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalTask>>(
      stream: widget.repo.watchOpenTasks(),
      builder: (ctx, snap) {
        final tasks = snap.data ?? [];

        if (tasks.isEmpty) {
          return const _EmptyOpen();
        }

        // Group tasks by customCategory
        final groups = <String?, List<PersonalTask>>{};
        for (final t in tasks) {
          groups.putIfAbsent(t.customCategory, () => []).add(t);
        }

        // Sort group keys: null (uncategorised) first, then alphabetical
        final groupKeys = groups.keys.toList()
          ..sort((a, b) {
            if (a == null) return -1;
            if (b == null) return 1;
            return a.compareTo(b);
          });

        // Build flat list: header + tasks per category
        final flatItems = <_ListItem>[];
        final showHeaders = groupKeys.length > 1 || groupKeys.first != null;

        for (final cat in groupKeys) {
          if (showHeaders) {
            flatItems.add(_HeaderItem(category: cat));
          }
          for (final t in groups[cat]!) {
            flatItems.add(_TaskItem(task: t));
          }
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dividerColor = isDark
            ? const Color(0xFF333333)
            : const Color(0xFFEEEEEE);

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: flatItems.length,
          itemBuilder: (context, index) {
            final item = flatItems[index];

            if (item is _HeaderItem) {
              return _CategoryHeader(
                key: ValueKey('header_${item.category}'),
                label: item.category ?? 'Geen categorie',
              );
            }

            final taskItem = item as _TaskItem;
            return _DraggableTaskRow(
              key: ValueKey(taskItem.task.id),
              index: index,
              task: taskItem.task,
              repo: widget.repo,
              hasFamilyKey: widget.hasFamilyKey,
              dividerColor: dividerColor,
            );
          },
          onReorder: (oldIndex, newIndex) {
            _onReorder(flatItems, oldIndex, newIndex);
          },
        );
      },
    );
  }

  void _onReorder(List<_ListItem> items, int oldIndex, int newIndex) {
    // Headers have no drag listener so this guard is just a safety net.
    if (items[oldIndex] is _HeaderItem) return;

    if (oldIndex < newIndex) newIndex -= 1;

    // Build the reordered list.
    final reordered = [...items]
      ..removeAt(oldIndex)
      ..insert(newIndex, items[oldIndex]);

    // Compute new category + sortOrder for every task in the reordered list.
    final updates = <({String id, String? category, int sortOrder})>[];
    String? currentCat;
    int posInCat = 0;

    for (final item in reordered) {
      if (item is _HeaderItem) {
        currentCat = item.category;
        posInCat = 0;
      } else {
        final taskItem = item as _TaskItem;
        updates.add((
          id: taskItem.task.id,
          category: currentCat,
          sortOrder: posInCat,
        ));
        posInCat++;
      }
    }

    widget.repo.batchUpdateCategoryAndOrder(updates);
  }
}

// ---------------------------------------------------------------------------
// Category header row
// ---------------------------------------------------------------------------

class _CategoryHeader extends StatelessWidget {
  final String label;

  const _CategoryHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task row with drag handle
// ---------------------------------------------------------------------------

class _DraggableTaskRow extends StatelessWidget {
  final int index;
  final PersonalTask task;
  final TodoRepository repo;
  final bool hasFamilyKey;
  final Color dividerColor;

  const _DraggableTaskRow({
    super.key,
    required this.index,
    required this.task,
    required this.repo,
    required this.hasFamilyKey,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TaskTile(task: task, repo: repo, hasFamilyKey: hasFamilyKey),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Icon(
              Icons.drag_handle,
              size: 20,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Completed tasks tab
// ---------------------------------------------------------------------------

class _CompletedTasksTab extends StatelessWidget {
  final TodoRepository repo;
  final bool hasFamilyKey;

  const _CompletedTasksTab({required this.repo, this.hasFamilyKey = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalTask>>(
      stream: repo.watchCompletedTasks(),
      builder: (ctx, snap) {
        final completed = snap.data ?? [];

        if (completed.isEmpty) {
          return const _EmptyCompleted();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dividerColor = isDark
            ? const Color(0xFF333333)
            : const Color(0xFFEEEEEE);

        final items = <Widget>[];

        // ── Delete all button ──────────────────────────────────────────────
        items.add(const SizedBox(height: 8));
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmDeleteAll(ctx, repo),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Verwijder alles'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        );

        // ── Completed task tiles ───────────────────────────────────────────
        for (var i = 0; i < completed.length; i++) {
          items.add(
            TaskTile(
              task: completed[i],
              repo: repo,
              hasFamilyKey: hasFamilyKey,
            ),
          );
          if (i < completed.length - 1)
            items.add(
              Divider(height: 1, indent: 0, endIndent: 0, color: dividerColor),
            );
        }
        items.add(const SizedBox(height: 80)); // room for QuickAddBar

        return ListView(children: items);
      },
    );
  }

  void _confirmDeleteAll(BuildContext context, TodoRepository repo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voltooide taken verwijderen'),
        content: const Text(
          'Weet je zeker dat je alle voltooide taken wilt verwijderen? Dit kan niet ongedaan worden gemaakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              repo.deleteCompletedTasks();
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

class _EmptyOpen extends StatelessWidget {
  const _EmptyOpen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Alles klaar!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Je hebt geen openstaande taken',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyCompleted extends StatelessWidget {
  const _EmptyCompleted();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Geen voltooide taken',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Voltooide taken verschijnen hier',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
