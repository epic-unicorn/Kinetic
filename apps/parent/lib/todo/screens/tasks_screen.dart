import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../../main.dart';
import '../../partner/models/partner_proposal.dart';
import '../../partner/services/partner_proposal_repository.dart';
import '../../settings/models/enrolled_kid.dart';
import '../../settings/settings_repository.dart';
import '../../sync/webdav_config_repository.dart';
import '../../theme/app_header.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/ai_suggestion_repository.dart';
import '../../todo/services/todo_repository.dart';
import '../../todo/widgets/quick_add_bar.dart';
import '../../todo/widgets/suggestion_banner.dart';
import '../../todo/widgets/task_detail_sheet.dart';
import '../../todo/widgets/task_tile.dart';

// ---------------------------------------------------------------------------
// TasksScreen — tabbed view: open tasks + completed tasks.
// ---------------------------------------------------------------------------

class TasksScreen extends StatefulWidget {
  final TodoRepository repo;
  final SettingsRepository? settingsRepo;
  final PartnerProposalRepository? proposalRepo;
  final AiSuggestionRepository? suggestionRepo;
  final String? myParentId;
  final ValueNotifier<SyncStatus>? syncStatus;
  final bool hasFamilyKey;
  final bool partnerPaired;
  final VoidCallback? onSyncRetry;
  final WebDavConfigRepository? configRepo;
  final int enrolledKidsCount;
  final ValueNotifier<int>? syncDoneCount;
  final SyncConfig? syncConfig;

  const TasksScreen({
    super.key,
    required this.repo,
    this.settingsRepo,
    this.proposalRepo,
    this.suggestionRepo,
    this.myParentId,
    this.syncStatus,
    this.hasFamilyKey = false,
    this.partnerPaired = false,
    this.onSyncRetry,
    this.configRepo,
    this.enrolledKidsCount = 0,
    this.syncDoneCount,
    this.syncConfig,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _pendingVoorstlagenCount = 0;
  StreamSubscription<int>? _pendingCountSub;
  final _kidsKey = GlobalKey<_KidsTasksTabState>();

  int get _tabCount => 2 + (widget.enrolledKidsCount > 0 ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _rebuildTabController();
    _pendingCountSub = widget.proposalRepo
        ?.watchPendingCount(myParentId: widget.myParentId)
        .listen((count) {
          if (mounted) setState(() => _pendingVoorstlagenCount = count);
        });
    widget.syncDoneCount?.addListener(_onSyncDone);
  }

  @override
  void didUpdateWidget(TasksScreen old) {
    super.didUpdateWidget(old);
    if (old.enrolledKidsCount != widget.enrolledKidsCount) {
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _rebuildTabController();
    }
    if (old.syncDoneCount != widget.syncDoneCount) {
      old.syncDoneCount?.removeListener(_onSyncDone);
      widget.syncDoneCount?.addListener(_onSyncDone);
    }
  }

  void _rebuildTabController() {
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (widget.enrolledKidsCount > 0 && _tabController.index == _tabCount - 1) {
      _kidsKey.currentState?._reload();
    }
  }

  void _onSyncDone() {
    if (widget.enrolledKidsCount > 0 && _tabController.index == _tabCount - 1) {
      _kidsKey.currentState?._reload();
    }
  }

  @override
  void dispose() {
    _pendingCountSub?.cancel();
    widget.syncDoneCount?.removeListener(_onSyncDone);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _showCompletedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CompletedBottomSheet(
        repo: widget.repo,
        hasFamilyKey: widget.hasFamilyKey,
      ),
    );
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
            icon: const Icon(Icons.delete_outlined),
            tooltip: 'Voltooide taken',
            onPressed: () => _showCompletedSheet(context),
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
          tabs: [
            const Tab(text: 'Privé'),
            Tab(
              child: Badge(
                isLabelVisible: _pendingVoorstlagenCount > 0,
                label: Text('$_pendingVoorstlagenCount'),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('Voorstellen'),
                ),
              ),
            ),
            if (widget.enrolledKidsCount > 0)
              const Tab(text: 'Kinderen'),
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
          _VoorstlagenTab(
            suggestionRepo: widget.suggestionRepo,
            todoRepo: widget.repo,
            proposalRepo: widget.proposalRepo,
            myParentId: widget.myParentId,
            partnerPaired: widget.partnerPaired,
            onSyncRequested: widget.onSyncRetry,
          ),
          if (widget.enrolledKidsCount > 0)
            _KidsTasksTab(
              key: _kidsKey,
              configRepo: widget.configRepo!,
              syncConfig: widget.syncConfig!,
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
    return switch (status) {
      SyncStatus.syncing => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      SyncStatus.error => IconButton(
        onPressed: onSyncPressed,
        tooltip: 'Sync mislukt, tap om opnieuw te proberen.',
        icon: Icon(
          Icons.sync_problem_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
      SyncStatus.idle => IconButton(
        onPressed: onSyncPressed,
        tooltip: 'Synchroniseren',
        icon: const Icon(Icons.cloud_done_outlined),
      ),
    };
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

        final listView = ReorderableListView.builder(
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

        return listView;
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
// Voorstellen tab — AI heuristic suggestions + partner proposals
// ---------------------------------------------------------------------------

class _VoorstlagenTab extends StatefulWidget {
  final AiSuggestionRepository? suggestionRepo;
  final TodoRepository todoRepo;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final bool partnerPaired;
  final VoidCallback? onSyncRequested;

  const _VoorstlagenTab({
    this.suggestionRepo,
    required this.todoRepo,
    this.proposalRepo,
    this.myParentId,
    this.partnerPaired = false,
    this.onSyncRequested,
  });

  @override
  State<_VoorstlagenTab> createState() => _VoorstlagenTabState();
}

class _VoorstlagenTabState extends State<_VoorstlagenTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.suggestionRepo != null)
          SuggestionBanner(
            suggestionRepo: widget.suggestionRepo!,
            todoRepo: widget.todoRepo,
            proposalRepo: widget.proposalRepo,
            myParentId: widget.myParentId,
            partnerPaired: widget.partnerPaired,
          ),
        Expanded(
          child: widget.proposalRepo != null
              ? _PartnerProposalsSection(
                  proposalRepository: widget.proposalRepo!,
                  myParentId: widget.myParentId,
                  onSyncRequested: widget.onSyncRequested,
                )
              : _EmptyVoorstellen(),
        ),
      ],
    );
  }
}

// Partner proposals section (within Voorstellen tab)
class _PartnerProposalsSection extends StatefulWidget {
  final PartnerProposalRepository proposalRepository;
  final String? myParentId;
  final VoidCallback? onSyncRequested;

  const _PartnerProposalsSection({
    required this.proposalRepository,
    this.myParentId,
    this.onSyncRequested,
  });

  @override
  State<_PartnerProposalsSection> createState() =>
      _PartnerProposalsSectionState();
}

class _PartnerProposalsSectionState extends State<_PartnerProposalsSection> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartnerProposal>>(
      stream: widget.proposalRepository.watchPending(
        myParentId: widget.myParentId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text('Fout bij laden van voorstellen'),
              ],
            ),
          );
        }
        final proposals = snapshot.data ?? [];
        if (proposals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Geen partnervoorstellen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Je partner heeft nog geen taken voorgesteld',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: proposals.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) =>
              _buildProposalCard(context, proposals[index]),
        );
      },
    );
  }

  Widget _buildProposalCard(BuildContext context, PartnerProposal proposal) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = _priorityColor(proposal.taskPriority, scheme);
    final dueSoon =
        proposal.taskDueDate != null &&
        proposal.taskDueDate!.isBefore(
          DateTime.now().add(const Duration(days: 3)),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.taskTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (proposal.taskNotes != null &&
                          proposal.taskNotes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            proposal.taskNotes!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    proposal.taskPriority.name,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: priorityColor),
                  ),
                ),
              ],
            ),
            if (proposal.taskDueDate != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(_formatDate(proposal.taskDueDate!)),
                backgroundColor: dueSoon
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: dueSoon ? scheme.onErrorContainer : null,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _dismissProposal(proposal.id),
                  child: const Text('Afwijzen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Accepteren'),
                  onPressed: () => _acceptProposal(proposal.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptProposal(String proposalId) async {
    await widget.proposalRepository.accept(proposalId);
    widget.onSyncRequested?.call();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voorstel geaccepteerd')));
    }
  }

  Future<void> _snoozeProposal(String proposalId) async {
    await widget.proposalRepository.snooze(proposalId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voorstel uitgesteld')));
    }
  }

  Future<void> _dismissProposal(String proposalId) async {
    await widget.proposalRepository.dismiss(proposalId);
    widget.onSyncRequested?.call();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voorstel afgewezen')));
    }
  }

  Future<void> _rejectProposal(PartnerProposal proposal) async {
    await widget.proposalRepository.reject(proposal.id, proposal.taskTitle);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemeld als slecht voorstel — we leren hiervan'),
        ),
      );
    }
  }

  Color _priorityColor(TaskPriority priority, ColorScheme scheme) =>
      switch (priority) {
        TaskPriority.high => scheme.error,
        TaskPriority.medium => scheme.primary,
        _ => scheme.outline,
      };

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Vandaag';
    if (diff == 1) return 'Morgen';
    if (diff < 7) return 'Over $diff dagen';
    return '${date.day}/${date.month}';
  }
}

// ---------------------------------------------------------------------------
// Kids tasks tab — pulls shared tasks from WebDAV grouped by enrolled kid.
// ---------------------------------------------------------------------------

class _KidsTasksTab extends StatefulWidget {
  final WebDavConfigRepository configRepo;
  final SyncConfig syncConfig;

  const _KidsTasksTab({
    super.key,
    required this.configRepo,
    required this.syncConfig,
  });

  @override
  State<_KidsTasksTab> createState() => _KidsTasksTabState();
}

class _KidsTasksTabState extends State<_KidsTasksTab> {
  late Future<_KidsTasksData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(_KidsTasksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncConfig != widget.syncConfig) {
      _future = _load();
    }
  }

  Future<_KidsTasksData> _load() async {
    final enrolledKids = await widget.configRepo.loadEnrolledKids();
    final client = WebDavClient(
      baseUrl: widget.syncConfig.baseUrl,
      username: widget.syncConfig.username,
      password: widget.syncConfig.password,
    );
    final service = WebDavSyncService(
      client: client,
      config: widget.syncConfig,
    );
    try {
      final tasks = await service.pullSharedTasks();
      // Compute total XP per kid label from completed tasks.
      final Map<String, int> xpPerKid = {};
      for (final task in tasks) {
        if (task.status != ICalTaskStatus.completed) continue;
        final targetId = _prop(task.description, 'xKineticTargetKidId');
        final xpStr = _prop(task.description, 'xKineticXpReward');
        final xp = int.tryParse(xpStr ?? '') ?? 0;
        String label;
        if (targetId == null || targetId.isEmpty) {
          label = 'Iedereen';
        } else {
          final kid = enrolledKids.cast<EnrolledKid?>().firstWhere(
            (k) => k?.id == targetId,
            orElse: () => null,
          );
          label = kid?.name ?? targetId;
        }
        xpPerKid[label] = (xpPerKid[label] ?? 0) + xp;
      }
      return _KidsTasksData(
        tasks: tasks,
        enrolledKids: enrolledKids,
        xpPerKid: xpPerKid,
      );
    } finally {
      client.dispose();
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _resetXp(String kidLabel, List<EnrolledKid> enrolledKids) async {
    final kid = enrolledKids.cast<EnrolledKid?>().firstWhere(
      (k) => k?.name == kidLabel,
      orElse: () => null,
    );
    if (kid == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('XP resetten voor ${kid.name}?'),
        content: const Text(
          'Dit stelt de XP-teller terug naar 0. '
          'De opdrachten blijven bewaard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetten'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final client = WebDavClient(
      baseUrl: widget.syncConfig.baseUrl,
      username: widget.syncConfig.username,
      password: widget.syncConfig.password,
    );
    final service = WebDavSyncService(client: client, config: widget.syncConfig);
    try {
      await service.pushXpReset(kid.id, DateTime.now().toUtc());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('XP gereset voor ${kid.name}')),
        );
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij resetten: $e')),
        );
      }
    } finally {
      client.dispose();
    }
  }

  String? _prop(String? desc, String key) {
    if (desc == null || desc.isEmpty) return null;
    final match = RegExp('$key:([^;]+)').firstMatch(desc);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_KidsTasksData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text('Fout bij laden van kinderopdrachten'),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw proberen'),
                  onPressed: _reload,
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        if (data.tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.child_care_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Geen kinderopdrachten',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stuur een taak naar de kinderenapp om hem hier te zien.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final Map<String, List<ICalTask>> grouped = {};
        for (final task in data.tasks) {
          final targetId = _prop(task.description, 'xKineticTargetKidId');
          String label;
          if (targetId == null || targetId.isEmpty) {
            label = 'Iedereen';
          } else {
            final kid = data.enrolledKids.cast<EnrolledKid?>().firstWhere(
              (k) => k?.id == targetId,
              orElse: () => null,
            );
            label = kid?.name ?? targetId;
          }
          grouped.putIfAbsent(label, () => []).add(task);
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${data.xpPerKid[entry.key] ?? 0} XP',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (entry.key != 'Iedereen') ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                          ),
                          onPressed: () =>
                              _resetXp(entry.key, data.enrolledKids),
                          child: const Text('Reset XP'),
                        ),
                      ],
                    ],
                  ),
                ),
                for (final task in entry.value) _KidsTaskTile(task: task),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KidsTasksData {
  final List<ICalTask> tasks;
  final List<EnrolledKid> enrolledKids;
  final Map<String, int> xpPerKid;
  const _KidsTasksData({
    required this.tasks,
    required this.enrolledKids,
    required this.xpPerKid,
  });
}

class _KidsTaskTile extends StatelessWidget {
  final ICalTask task;
  const _KidsTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompleted = task.status == ICalTaskStatus.completed;
    final due = task.dueAt;
    final completedAt = isCompleted ? task.updatedAt.toLocal() : null;

    final subtitleParts = <String>[];
    if (due != null) {
      subtitleParts.add('${due.toLocal().day}/${due.toLocal().month}');
    }
    if (completedAt != null) {
      subtitleParts.add(
        'Gedaan op ${completedAt.day}/${completedAt.month}',
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // Non-interactive indicator — parent cannot complete kid tasks
      leading: Icon(
        isCompleted ? Icons.check_circle : Icons.hourglass_empty_rounded,
        color: isCompleted ? scheme.primary : scheme.outline,
      ),
      title: Text(
        task.summary,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? scheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: subtitleParts.isNotEmpty
          ? Text(
              subtitleParts.join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isCompleted ? scheme.primary : null,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Completed tasks — shown as a draggable bottom sheet via the trash icon
// ---------------------------------------------------------------------------

class _CompletedBottomSheet extends StatelessWidget {
  final TodoRepository repo;
  final bool hasFamilyKey;

  const _CompletedBottomSheet({required this.repo, this.hasFamilyKey = false});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (context, scrollController) => StreamBuilder<List<PersonalTask>>(
        stream: repo.watchCompletedTasks(),
        builder: (ctx, snap) {
          final completed = snap.data ?? [];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dividerColor = isDark
              ? const Color(0xFF333333)
              : const Color(0xFFEEEEEE);

          return Column(
            children: [
              // ── drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── header row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Voltooide taken',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (completed.isNotEmpty)
                      TextButton.icon(
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
                  ],
                ),
              ),
              const Divider(height: 1),
              // ── content ─────────────────────────────────────────────────
              if (completed.isEmpty)
                const Expanded(child: _EmptyCompleted())
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: completed.length,
                    separatorBuilder: (context, _) =>
                        Divider(height: 1, color: dividerColor),
                    itemBuilder: (_, i) => TaskTile(
                      task: completed[i],
                      repo: repo,
                      hasFamilyKey: hasFamilyKey,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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

class _EmptyVoorstellen extends StatelessWidget {
  const _EmptyVoorstellen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Geen voorstellen',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Hier verschijnen suggesties van de slimme\nplanner en voorstellen van je partner',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

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
