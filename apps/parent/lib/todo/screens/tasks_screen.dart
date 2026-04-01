import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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

  const TasksScreen({super.key, required this.repo});

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
        title: const Text('Taken'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => TaskDetailSheet(repo: widget.repo),
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
          _OpenTasksTab(repo: widget.repo),
          _CompletedTasksTab(repo: widget.repo),
        ],
      ),
      bottomSheet: QuickAddBar(repo: widget.repo),
    );
  }
}

// ---------------------------------------------------------------------------
// Open tasks tab
// ---------------------------------------------------------------------------

class _OpenTasksTab extends StatelessWidget {
  final TodoRepository repo;

  const _OpenTasksTab({required this.repo});

  static const _divider = Divider(height: 1, indent: 52, endIndent: 0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalTask>>(
      stream: repo.watchOpenTasks(),
      builder: (ctx, snap) {
        final open = snap.data ?? [];

        if (open.isEmpty) {
          return const _EmptyOpen();
        }

        final items = <Widget>[];
        for (var i = 0; i < open.length; i++) {
          items.add(TaskTile(task: open[i], repo: repo));
          if (i < open.length - 1) items.add(_divider);
        }
        items.add(const SizedBox(height: 80)); // room for QuickAddBar

        return ListView(children: items);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Completed tasks tab
// ---------------------------------------------------------------------------

class _CompletedTasksTab extends StatelessWidget {
  final TodoRepository repo;

  const _CompletedTasksTab({required this.repo});

  static const _divider = Divider(height: 1, indent: 52, endIndent: 0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalTask>>(
      stream: repo.watchCompletedTasks(),
      builder: (ctx, snap) {
        final completed = snap.data ?? [];

        if (completed.isEmpty) {
          return const _EmptyCompleted();
        }

        final items = <Widget>[];

        // ── Delete all button ──────────────────────────────────────────────
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
                  foregroundColor: kColorWarmGrey,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        );

        // ── Completed task tiles ───────────────────────────────────────────
        for (var i = 0; i < completed.length; i++) {
          items.add(TaskTile(task: completed[i], repo: repo));
          if (i < completed.length - 1) items.add(_divider);
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: kColorWarmGrey.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            'Alles klaar!',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kColorWarmGrey),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: kColorWarmGrey.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            'Geen voltooide taken',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kColorWarmGrey),
          ),
        ],
      ),
    );
  }
}
