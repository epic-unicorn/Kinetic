import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import '../services/load_sync_service.dart';

// ---------------------------------------------------------------------------
// PartnerScreen â€” shows incoming task proposals from your partner and the
// shared tasks both parents can see once a proposal is accepted.
// ---------------------------------------------------------------------------

class PartnerScreen extends StatefulWidget {
  final TodoRepository repo;
  final LoadSyncService loadSyncService;

  /// Passed from _RootShellState so didUpdateWidget detects sync events.
  final SyncStatus syncStatus;

  const PartnerScreen({
    super.key,
    required this.repo,
    required this.loadSyncService,
    required this.syncStatus,
  });

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  List<PartnerProposal> _proposals = [];
  List<SharedTask> _sharedTasks = [];

  late final StreamSubscription<List<PartnerProposal>> _proposalSub;

  @override
  void initState() {
    super.initState();
    _proposalSub = widget.repo.watchPendingProposals().listen((proposals) {
      setState(() => _proposals = proposals);
    });
    _refreshSharedTasks();
  }

  @override
  void didUpdateWidget(PartnerScreen old) {
    super.didUpdateWidget(old);
    if (widget.syncStatus != old.syncStatus) {
      widget.loadSyncService.syncIncomingProposals(widget.repo).then((_) {
        if (mounted) _refreshSharedTasks();
      });
    }
  }

  void _refreshSharedTasks() {
    setState(() {
      _sharedTasks = widget.loadSyncService.sharedTasks;
    });
  }

  @override
  void dispose() {
    _proposalSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _proposals.isEmpty && _sharedTasks.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Partner'), centerTitle: false),
      body: isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_proposals.isNotEmpty) ...[
                  _ProposalInboxSection(
                    proposals: _proposals,
                    repo: widget.repo,
                    loadSyncService: widget.loadSyncService,
                    onAccepted: _refreshSharedTasks,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_sharedTasks.isNotEmpty)
                  _SharedTasksSection(tasks: _sharedTasks),
              ],
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Nog geen voorstellen',
            style: tt.bodyMedium?.copyWith(color: kColorWarmGrey),
          ),
          const SizedBox(height: 6),
          Text(
            'Wanneer je partner een taak voorstelt,\nverschijnt die hier.',
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ── Proposal inbox ────────────────────────────────────────────────────────────

class _ProposalInboxSection extends StatelessWidget {
  final List<PartnerProposal> proposals;
  final TodoRepository repo;
  final LoadSyncService loadSyncService;
  final VoidCallback onAccepted;

  const _ProposalInboxSection({
    required this.proposals,
    required this.repo,
    required this.loadSyncService,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Van je partner',
              style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: proposals.length),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in proposals)
          _ProposalCard(
            proposal: p,
            repo: repo,
            loadSyncService: loadSyncService,
            onAccepted: onAccepted,
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kColorTeal.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: kColorTeal),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final PartnerProposal proposal;
  final TodoRepository repo;
  final LoadSyncService loadSyncService;
  final VoidCallback onAccepted;

  const _ProposalCard({
    required this.proposal,
    required this.repo,
    required this.loadSyncService,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pColor = priorityColor(proposal.taskPriority);
    final catLabel = switch (proposal.taskCategory) {
      TaskCategory.household => 'Huishouden',
      TaskCategory.health => 'Gezondheid',
      TaskCategory.admin => 'Administratie',
      TaskCategory.school => 'School',
      TaskCategory.finance => 'Financiën',
      TaskCategory.other => 'Overig',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon(proposal.taskCategory),
                  size: 20,
                  color: kColorWarmGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(proposal.taskTitle, style: tt.bodyMedium),
                      Text(
                        catLabel,
                        style: tt.labelSmall?.copyWith(color: kColorWarmGrey),
                      ),
                    ],
                  ),
                ),
                if (proposal.taskPriority != TaskPriority.none)
                  Text(
                    priorityLabel(proposal.taskPriority),
                    style: TextStyle(
                      color: pColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionChip(
                  label: 'Accepteren',
                  color: kColorTeal,
                  onTap: () {
                    // Create a local task from the proposal, preserving its
                    // category so the classifier does not misidentify it.
                    repo.createTask(
                      title: proposal.taskTitle,
                      priority: proposal.taskPriority,
                      dueDate: proposal.taskDueDate,
                      category: proposal.taskCategory,
                    );
                    // Write a shared_task doc so the sending partner can see
                    // this was accepted.
                    loadSyncService.acceptProposal(proposal);
                    repo.updateProposalStatus(
                      proposal.id,
                      ProposalStatus.accepted,
                    );
                    onAccepted();
                  },
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Uitstellen',
                  color: kColorWarmGrey,
                  onTap: () => repo.updateProposalStatus(
                    proposal.id,
                    ProposalStatus.snoozed,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Afwijzen',
                  color: Colors.redAccent,
                  onTap: () => repo.updateProposalStatus(
                    proposal.id,
                    ProposalStatus.dismissed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

// ── Shared tasks ──────────────────────────────────────────────────────────────

class _SharedTasksSection extends StatelessWidget {
  final List<SharedTask> tasks;

  const _SharedTasksSection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gedeelde taken',
          style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
        ),
        const SizedBox(height: 2),
        Text(
          'Geaccepteerde voorstellen — zichtbaar voor jullie beiden.',
          style: tt.labelSmall?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 8),
        for (final t in tasks) _SharedTaskCard(task: t),
      ],
    );
  }
}

class _SharedTaskCard extends StatelessWidget {
  final SharedTask task;

  const _SharedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final catLabel = switch (task.taskCategory) {
      TaskCategory.household => 'Huishouden',
      TaskCategory.health => 'Gezondheid',
      TaskCategory.admin => 'Administratie',
      TaskCategory.school => 'School',
      TaskCategory.finance => 'Financiën',
      TaskCategory.other => 'Overig',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(categoryIcon(task.taskCategory), color: kColorWarmGrey),
        title: Text(task.taskTitle, style: tt.bodyMedium),
        subtitle: Text(
          catLabel,
          style: tt.labelSmall?.copyWith(color: kColorWarmGrey),
        ),
        trailing: const Icon(
          Icons.check_circle_outline,
          color: kColorTeal,
          size: 20,
        ),
      ),
    );
  }
}
