import 'package:flutter/material.dart';

import '../../main.dart';
import '../../partner/services/partner_proposal_repository.dart';
import '../../settings/settings_repository.dart';
import '../../sync/webdav_config_repository.dart';
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
  final SettingsRepository? settingsRepo;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final ValueNotifier<SyncStatus>? syncStatus;
  final bool hasFamilyKey;
  final VoidCallback? onSyncRetry;
  final WebDavConfigRepository? configRepo;

  const TasksScreen({
    super.key,
    required this.repo,
    this.settingsRepo,
    this.proposalRepo,
    this.myParentId,
    this.syncStatus,
    this.hasFamilyKey = false,
    this.onSyncRetry,
    this.configRepo,
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
              builder: (context, status, _) =>
                  _SyncIcon(status: status, onSyncPressed: widget.onSyncRetry),
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
                configRepo: widget.configRepo,
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
          _OpenTasksTab(
            repo: widget.repo,
            hasFamilyKey: widget.hasFamilyKey,
            settingsRepo: widget.settingsRepo,
            proposalRepo: widget.proposalRepo,
            myParentId: widget.myParentId,
            configRepo: widget.configRepo,
          ),
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
  final VoidCallback? onSyncPressed;

  const _SyncIcon({required this.status, this.onSyncPressed});

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
          onTap: onSyncPressed,
          child: Tooltip(
            message: 'Sync mislukt, tap om opnieuw te proberen.',
            child: Icon(
              Icons.sync_problem_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        SyncStatus.idle => GestureDetector(
          onTap: onSyncPressed,
          child: Tooltip(
            message: 'Synchroniseren',
            child: Icon(
              Icons.cloud_done_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
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
  final SettingsRepository? settingsRepo;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final WebDavConfigRepository? configRepo;

  const _OpenTasksTab({
    required this.repo,
    this.hasFamilyKey = false,
    this.settingsRepo,
    this.proposalRepo,
    this.myParentId,
    this.configRepo,
  });

  @override
  State<_OpenTasksTab> createState() => _OpenTasksTabState();
}

class _OpenTasksTabState extends State<_OpenTasksTab> {
  /// User-defined category order. Persists across app restarts.
  /// Null entry represents the uncategorised bucket.
  List<String?> _categoryOrder = [];

  /// Merges stream categories with the current user-defined order.
  /// New categories are appended; removed categories are dropped.
  List<String?> _mergeOrder(Iterable<String?> streamKeys) {
    final known = Set<String?>.from(streamKeys);
    // Preserve existing order for categories still present.
    final merged = _categoryOrder.where(known.contains).toList();
    // Append any new categories not yet in the order list.
    for (final k in streamKeys) {
      if (!merged.contains(k)) merged.add(k);
    }
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    if (widget.settingsRepo == null) return;
    final saved = await widget.settingsRepo!.loadTaskCategoryOrder();
    if (mounted) setState(() => _categoryOrder = saved);
  }

  void _saveCategoryOrder(List<String?> order) {
    widget.settingsRepo?.saveTaskCategoryOrder(order);
  }

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

        // Keep _categoryOrder in sync with available categories.
        final merged = _mergeOrder(groups.keys);
        if (merged.length != _categoryOrder.length ||
            !merged.every(_categoryOrder.contains)) {
          // Use post-frame callback to avoid calling setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _categoryOrder = _mergeOrder(groups.keys));
            }
          });
        }

        // Build sorted group key list using user-defined order.
        final groupKeys = merged.where(groups.containsKey).toList();

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
                index: index,
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
              proposalRepo: widget.proposalRepo,
              myParentId: widget.myParentId,
              configRepo: widget.configRepo,
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
    if (oldIndex < newIndex) newIndex -= 1;

    if (items[oldIndex] is _HeaderItem) {
      // ── Category header drag: reorder the category block ─────────────────
      // Simulate the reorder in the flat list to derive the new category order.
      final reordered = [...items]
        ..removeAt(oldIndex)
        ..insert(newIndex, items[oldIndex]);
      final newOrder = <String?>[];
      for (final item in reordered) {
        if (item is _HeaderItem) newOrder.add(item.category);
      }
      setState(() => _categoryOrder = newOrder);
      _saveCategoryOrder(newOrder);
      return;
    }

    // ── Task drag: update category + sort order ───────────────────────────
    final reordered = [...items]
      ..removeAt(oldIndex)
      ..insert(newIndex, items[oldIndex]);

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
  final int index;

  const _CategoryHeader({super.key, required this.label, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ],
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
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final WebDavConfigRepository? configRepo;

  const _DraggableTaskRow({
    super.key,
    required this.index,
    required this.task,
    required this.repo,
    required this.hasFamilyKey,
    required this.dividerColor,
    this.proposalRepo,
    this.myParentId,
    this.configRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TaskTile(
            task: task,
            repo: repo,
            hasFamilyKey: hasFamilyKey,
            proposalRepo: proposalRepo,
            myParentId: myParentId,
            configRepo: configRepo,
          ),
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
