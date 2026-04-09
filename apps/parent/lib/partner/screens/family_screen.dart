import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../../settings/models/enrolled_kid.dart';
import '../../sync/webdav_config_repository.dart';
import '../../theme/app_header.dart';
import '../../todo/models/enums.dart';
import '../models/partner_proposal.dart';
import '../services/partner_proposal_repository.dart';

/// FamilyScreen — proposals from partner (Voorstellen tab) and
/// kids assignments overview (Kinderen tab).
///
/// Tabs are conditionally shown based on connection status.
/// The Kinderen tab reloads whenever it becomes the active tab so that data
/// pushed during a background sync is visible without a manual refresh.
class FamilyScreen extends StatefulWidget {
  final PartnerProposalRepository proposalRepository;
  final String? myParentId;
  final WebDavConfigRepository configRepo;
  final SyncConfig syncConfig;
  final bool partnerPaired;
  final int enrolledKidsCount;
  final ValueNotifier<int>? syncDoneCount;

  const FamilyScreen({
    super.key,
    required this.proposalRepository,
    this.myParentId,
    required this.configRepo,
    required this.syncConfig,
    required this.partnerPaired,
    required this.enrolledKidsCount,
    this.syncDoneCount,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  final _kidsKey = GlobalKey<_KidsTasksTabState>();

  int get _tabCount {
    int c = 0;
    if (widget.partnerPaired) c++;
    if (widget.enrolledKidsCount > 0) c++;
    return c;
  }

  // Index of the Kinderen tab within the current tab bar (depends on whether
  // the Voorstellen tab is also present).
  int get _kidsTabIndex => widget.partnerPaired ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _rebuildController();
    widget.syncDoneCount?.addListener(_onSyncDone);
  }

  @override
  void didUpdateWidget(FamilyScreen old) {
    super.didUpdateWidget(old);
    if (old.syncDoneCount != widget.syncDoneCount) {
      old.syncDoneCount?.removeListener(_onSyncDone);
      widget.syncDoneCount?.addListener(_onSyncDone);
    }
    if (_tabCount != (_tabs?.length ?? 0)) {
      _tabs?.removeListener(_onTabChanged);
      _tabs?.dispose();
      _rebuildController();
    }
  }

  void _onSyncDone() {
    if (widget.enrolledKidsCount > 0 &&
        _tabs != null &&
        _tabs!.index == _kidsTabIndex) {
      _kidsKey.currentState?._reload();
    }
  }

  void _rebuildController() {
    final count = _tabCount;
    if (count > 0) {
      _tabs = TabController(length: count, vsync: this)
        ..addListener(_onTabChanged);
    } else {
      _tabs = null;
    }
  }

  void _onTabChanged() {
    if (_tabs == null || _tabs!.indexIsChanging) return;
    if (widget.enrolledKidsCount > 0 && _tabs!.index == _kidsTabIndex) {
      _kidsKey.currentState?._reload();
    }
  }

  @override
  void dispose() {
    widget.syncDoneCount?.removeListener(_onSyncDone);
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _tabCount;
    if (count == 0) {
      return Scaffold(
        appBar: AppBar(
          title: AppHeader(title: 'Familie', centerTitle: false),
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Familie niet ingesteld',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Koppel een partner of kinderen in Instellingen',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: AppHeader(title: 'Familie', centerTitle: false),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            if (widget.partnerPaired)
              const Tab(icon: Icon(Icons.swap_horiz), text: 'Voorstellen'),
            if (widget.enrolledKidsCount > 0)
              const Tab(icon: Icon(Icons.child_care), text: 'Kinderen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          if (widget.partnerPaired)
            _ProposalsTab(
              proposalRepository: widget.proposalRepository,
              myParentId: widget.myParentId,
            ),
          if (widget.enrolledKidsCount > 0)
            _KidsTasksTab(
              key: _kidsKey,
              configRepo: widget.configRepo,
              syncConfig: widget.syncConfig,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proposals tab (ported from PartnerScreen)
// ---------------------------------------------------------------------------

class _ProposalsTab extends StatefulWidget {
  final PartnerProposalRepository proposalRepository;
  final String? myParentId;

  const _ProposalsTab({required this.proposalRepository, this.myParentId});

  @override
  State<_ProposalsTab> createState() => _ProposalsTabState();
}

class _ProposalsTabState extends State<_ProposalsTab> {
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
                  Icons.inbox_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Geen voorstellen',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Je partner heeft nog geen taken naar jou gestuurd.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            const SizedBox(height: 8),
            Row(
              children: [
                if (proposal.taskDueDate != null)
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
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_down_outlined),
                  tooltip: 'Slecht voorstel',
                  color: scheme.outline,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _rejectProposal(proposal),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _dismissProposal(proposal.id),
                  child: const Text('Afwijzen'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _snoozeProposal(proposal.id),
                  child: const Text('Later'),
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
    return '${date.month}/${date.day}';
  }
}

// ---------------------------------------------------------------------------
// Kids tasks tab — pulls shared tasks from WebDAV in-memory and shows
// them grouped by the enrolled kid they are assigned to.
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
      return _KidsTasksData(tasks: tasks, enrolledKids: enrolledKids);
    } finally {
      client.dispose();
    }
  }

  void _reload() => setState(() => _future = _load());

  /// Extract a custom property from the iCal DESCRIPTION field.
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

        // Group tasks by targeted kid. Tasks with no targetKidId go in "Iedereen".
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
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
  const _KidsTasksData({required this.tasks, required this.enrolledKids});
}

class _KidsTaskTile extends StatelessWidget {
  final ICalTask task;
  const _KidsTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == ICalTaskStatus.completed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isCompleted
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        task.summary,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      subtitle: task.dueAt != null
          ? Text(
              '${task.dueAt!.toLocal().day}/${task.dueAt!.toLocal().month}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
    );
  }
}
