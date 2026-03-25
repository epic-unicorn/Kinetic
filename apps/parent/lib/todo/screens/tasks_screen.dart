import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/mission_converter_service.dart';
import '../../todo/services/todo_repository.dart';
import '../../todo/widgets/quick_add_bar.dart';
import '../../todo/widgets/task_detail_sheet.dart';
import '../../todo/widgets/task_tile.dart';

// ---------------------------------------------------------------------------
// Smart list identifiers (not real listId's — just view keys)
// ---------------------------------------------------------------------------

const _kSmartToday = '__today__';
const _kSmartScheduled = '__scheduled__';
const _kSmartFlagged = '__flagged__';
const _kSmartAll = '__all__';

// ---------------------------------------------------------------------------
// TasksScreen
// ---------------------------------------------------------------------------

class TasksScreen extends StatefulWidget {
  final TodoRepository repo;
  final MissionConverterService? converter;

  const TasksScreen({super.key, required this.repo, this.converter});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _activeView = _kSmartToday;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_viewTitle(_activeView)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => TaskDetailSheet(
                repo: widget.repo,
                initialListId: _realListId(_activeView),
                converter: widget.converter,
              ),
            ),
          ),
        ],
      ),
      // ── Sidebar drawer: smart lists + user lists ─────────────────────────
      drawer: _ListDrawer(
        repo: widget.repo,
        activeView: _activeView,
        onSelect: (view) {
          setState(() => _activeView = view);
          Navigator.pop(context);
        },
      ),
      body: Column(
        children: [
          // ── Horizontal smart-list chips (quick access without drawer) ────
          _SmartListChips(
            activeView: _activeView,
            onSelect: (v) => setState(() => _activeView = v),
          ),
          // ── Task stream ──────────────────────────────────────────────────
          Expanded(
            child: _TaskListView(
              repo: widget.repo,
              view: _activeView,
              converter: widget.converter,
            ),
          ),
        ],
      ),
      bottomSheet: QuickAddBar(
        repo: widget.repo,
        activeListId: _realListId(_activeView),
      ),
    );
  }

  String _viewTitle(String view) => switch (view) {
    _kSmartToday => 'Vandaag',
    _kSmartScheduled => 'Gepland',
    _kSmartFlagged => 'Gemarkeerd',
    _kSmartAll => 'Alle taken',
    _ => view, // user list name passed separately via state
  };

  /// Returns a real listId for task creation, null for smart lists.
  String? _realListId(String view) => view.startsWith('__') ? null : view;
}

// ---------------------------------------------------------------------------
// Horizontal smart-list chips
// ---------------------------------------------------------------------------

class _SmartListChips extends StatelessWidget {
  final String activeView;
  final ValueChanged<String> onSelect;

  const _SmartListChips({required this.activeView, required this.onSelect});

  static const _chips = <(String, IconData, String)>[
    ('Vandaag', Icons.wb_sunny_outlined, _kSmartToday),
    ('Gepland', Icons.calendar_month, _kSmartScheduled),
    ('Gemarkeerd', Icons.flag_outlined, _kSmartFlagged),
    ('Alles', Icons.list_alt_outlined, _kSmartAll),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, icon, key) = _chips[i];
          final selected = activeView == key;
          return ChoiceChip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelect(key),
            selectedColor: kColorTeal.withAlpha(50),
            labelStyle: TextStyle(
              color: selected ? kColorTeal : kColorWarmGrey,
              fontSize: 13,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The actual scrollable task list for the active view
// ---------------------------------------------------------------------------

class _TaskListView extends StatelessWidget {
  final TodoRepository repo;
  final String view;
  final MissionConverterService? converter;

  const _TaskListView({required this.repo, required this.view, this.converter});

  @override
  Widget build(BuildContext context) {
    final stream = switch (view) {
      _kSmartToday => repo.watchTodayTasks(),
      _kSmartScheduled => repo.watchScheduledTasks(),
      _kSmartFlagged => repo.watchFlaggedTasks(),
      _kSmartAll => repo.watchAllTasks(),
      _ => repo.watchTasksInList(view),
    };

    return StreamBuilder<List<PersonalTask>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snap.data ?? [];
        if (tasks.isEmpty) {
          return _EmptyView(view: view);
        }
        return ListView.separated(
          // Leave room for the QuickAddBar at the bottom
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 52,
            color: kColorWarmGrey.withAlpha(30),
          ),
          itemBuilder: (_, i) =>
              TaskTile(task: tasks[i], repo: repo, converter: converter),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  final String view;
  const _EmptyView({required this.view});

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (view) {
      _kSmartToday => (Icons.wb_sunny_outlined, 'Niets voor vandaag'),
      _kSmartFlagged => (Icons.flag_outlined, 'Geen gemarkeerde taken'),
      _kSmartScheduled => (Icons.event_available, 'Geen geplande taken'),
      _ => (Icons.check_circle_outline, 'Alles klaar!'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: kColorWarmGrey.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kColorWarmGrey),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left drawer — smart lists + user lists + new list button
// ---------------------------------------------------------------------------

class _ListDrawer extends StatelessWidget {
  final TodoRepository repo;
  final String activeView;
  final ValueChanged<String> onSelect;

  const _ListDrawer({
    required this.repo,
    required this.activeView,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Lijsten',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            // ── Smart lists ─────────────────────────────────────────────────
            _DrawerItem(
              icon: Icons.wb_sunny_outlined,
              label: 'Vandaag',
              selected: activeView == _kSmartToday,
              onTap: () => onSelect(_kSmartToday),
            ),
            _DrawerItem(
              icon: Icons.calendar_month,
              label: 'Gepland',
              selected: activeView == _kSmartScheduled,
              onTap: () => onSelect(_kSmartScheduled),
            ),
            _DrawerItem(
              icon: Icons.flag_outlined,
              label: 'Gemarkeerd',
              selected: activeView == _kSmartFlagged,
              onTap: () => onSelect(_kSmartFlagged),
            ),
            _DrawerItem(
              icon: Icons.list_alt_outlined,
              label: 'Alle taken',
              selected: activeView == _kSmartAll,
              onTap: () => onSelect(_kSmartAll),
            ),

            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Mijn lijsten',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: kColorWarmGrey),
              ),
            ),

            // ── User lists ───────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder(
                stream: repo.watchLists(),
                builder: (context, snap) {
                  final lists = snap.data ?? [];
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final list in lists)
                        _DrawerItem(
                          icon: IconData(
                            list.iconCodePoint,
                            fontFamily: 'MaterialIcons',
                          ),
                          label: list.name,
                          selected: activeView == list.id,
                          color: Color(list.colorValue),
                          onTap: () => onSelect(list.id),
                        ),
                    ],
                  );
                },
              ),
            ),

            // ── New list ─────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.add, color: kColorTeal),
              title: const Text(
                'Nieuwe lijst',
                style: TextStyle(color: kColorTeal),
              ),
              onTap: () => _newList(context),
            ),
          ],
        ),
      ),
    );
  }

  void _newList(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nieuwe lijst'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Lijstnaam'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _createAndPop(ctx, ctrl, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => _createAndPop(ctx, ctrl, context),
            child: const Text('Aanmaken'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAndPop(
    BuildContext dialogCtx,
    TextEditingController ctrl,
    BuildContext drawerCtx,
  ) async {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final list = await repo.createList(name: name);
    if (!dialogCtx.mounted) return;
    Navigator.pop(dialogCtx);
    onSelect(list.id);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (selected ? kColorTeal : kColorWarmGrey);
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? kColorTeal : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      selectedTileColor: kColorTeal.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}
