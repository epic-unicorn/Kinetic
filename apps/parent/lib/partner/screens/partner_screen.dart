import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import '../models/load_snapshot.dart';
import '../services/load_analyzer.dart';
import '../services/load_sync_service.dart';

// ---------------------------------------------------------------------------
// Threshold: surface suggestions only when one parent carries at least this
// many points more than the other.
// ---------------------------------------------------------------------------

const _kImbalanceThreshold = 4.0;

// ---------------------------------------------------------------------------
// PartnerScreen — Phase C load-balancing & proposal UI.
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
  LoadSnapshot _myLoad = LoadSnapshot.empty();
  List<PersonalTask> _tasks = [];
  List<PartnerProposal> _proposals = [];

  late final StreamSubscription<List<PersonalTask>> _taskSub;
  late final StreamSubscription<List<PartnerProposal>> _proposalSub;

  @override
  void initState() {
    super.initState();

    _taskSub = widget.repo.watchAllTasks().listen((tasks) {
      final newLoad = LoadAnalyzer.analyze(tasks);
      setState(() {
        _tasks = tasks;
        _myLoad = newLoad;
      });
      widget.loadSyncService.publishMyLoad(newLoad);
    });

    _proposalSub = widget.repo.watchPendingProposals().listen((proposals) {
      setState(() => _proposals = proposals);
    });
  }

  @override
  void didUpdateWidget(PartnerScreen old) {
    super.didUpdateWidget(old);
    // Import new proposals whenever the sync state changes.
    if (widget.syncStatus != old.syncStatus) {
      widget.loadSyncService.syncIncomingProposals(widget.repo);
    }
  }

  @override
  void dispose() {
    _taskSub.cancel();
    _proposalSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnerLoad = widget.loadSyncService.partnerLoad;

    // Suggestion candidates: non-private, non-completed, not urgently due.
    final urgentCutoff = DateTime.now().toUtc().add(const Duration(hours: 24));
    final candidates =
        (_tasks
                .where(
                  (t) =>
                      !t.isCompleted &&
                      !t.isPrivate &&
                      (t.dueDate == null || t.dueDate!.isAfter(urgentCutoff)),
                )
                .toList()
              ..sort((a, b) => b.priority.index.compareTo(a.priority.index)))
            .take(3)
            .toList();

    final showSuggestions =
        partnerLoad != null &&
        _myLoad.total > partnerLoad.snapshot.total + _kImbalanceThreshold &&
        candidates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Partner'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _BalanceCard(myLoad: _myLoad, partnerLoad: partnerLoad?.snapshot),
          const SizedBox(height: 12),
          if (_myLoad.total > 0) ...[
            _CategoryBreakdownCard(snapshot: _myLoad),
            const SizedBox(height: 12),
          ],
          if (_proposals.isNotEmpty) ...[
            _ProposalInboxSection(proposals: _proposals, repo: widget.repo),
            const SizedBox(height: 12),
          ],
          if (showSuggestions)
            _SuggestionSection(
              candidates: candidates,
              partnerDeviceId: partnerLoad.deviceId,
              loadSyncService: widget.loadSyncService,
            ),
        ],
      ),
    );
  }
}

// ── Balance card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final LoadSnapshot myLoad;
  final LoadSnapshot? partnerLoad;

  const _BalanceCard({required this.myLoad, required this.partnerLoad});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final maxLoad = [
      myLoad.total,
      partnerLoad?.total ?? 0,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    final myFrac = myLoad.total / maxLoad;
    final partnerFrac = (partnerLoad?.total ?? 0) / maxLoad;

    final diff = (myLoad.total - (partnerLoad?.total ?? 0)).abs();
    final moreLoaded = myLoad.total >= (partnerLoad?.total ?? 0)
        ? 'You'
        : 'Partner';

    final balanceLabel = partnerLoad == null
        ? 'Waiting for partner\u2019s data\u2026'
        : diff < 2
        ? 'Balanced \u2713'
        : '$moreLoaded ${diff.toStringAsFixed(1)} pts more';

    final balanceColor = partnerLoad == null
        ? kColorWarmGrey
        : diff < 2
        ? kColorTeal
        : diff > _kImbalanceThreshold
        ? Colors.redAccent
        : kColorGold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance',
              style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
            ),
            const SizedBox(height: 16),
            _LoadBar(
              label: 'You',
              fraction: myFrac,
              score: myLoad.total,
              color: kColorTeal,
            ),
            const SizedBox(height: 8),
            _LoadBar(
              label: 'Partner',
              fraction: partnerFrac,
              score: partnerLoad?.total ?? 0,
              color: partnerLoad == null ? Colors.white24 : kColorGold,
              placeholder: partnerLoad == null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  (diff < 2 || partnerLoad == null)
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  size: 14,
                  color: balanceColor,
                ),
                const SizedBox(width: 6),
                Text(
                  balanceLabel,
                  style: tt.labelSmall?.copyWith(color: balanceColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  final String label;
  final double fraction;
  final double score;
  final Color color;
  final bool placeholder;

  const _LoadBar({
    required this.label,
    required this.fraction,
    required this.score,
    required this.color,
    this.placeholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: kColorWarmGrey),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  placeholder ? Colors.white12 : color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            placeholder ? '\u2014' : score.toStringAsFixed(1),
            style: tt.labelMedium?.copyWith(
              color: placeholder ? Colors.white24 : kColorOffWhite,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ── Category breakdown card ───────────────────────────────────────────────────

class _CategoryBreakdownCard extends StatelessWidget {
  final LoadSnapshot snapshot;

  const _CategoryBreakdownCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final maxCatScore = snapshot.perCategory.values.fold(
      1.0,
      (m, v) => v > m ? v : m,
    );

    final cats = snapshot.perCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (cats.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By category',
              style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
            ),
            const SizedBox(height: 12),
            for (final e in cats) ...[
              _CategoryRow(
                category: e.key,
                score: e.value,
                maxScore: maxCatScore,
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final TaskCategory category;
  final double score;
  final double maxScore;

  const _CategoryRow({
    required this.category,
    required this.score,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final frac = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    final label = category.name[0].toUpperCase() + category.name.substring(1);

    return Row(
      children: [
        Icon(categoryIcon(category), size: 16, color: kColorWarmGrey),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: kColorWarmGrey),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(kColorTeal),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          score.toStringAsFixed(1),
          style: tt.labelSmall?.copyWith(color: Colors.white54),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

// ── Proposal inbox ────────────────────────────────────────────────────────────

class _ProposalInboxSection extends StatelessWidget {
  final List<PartnerProposal> proposals;
  final TodoRepository repo;

  const _ProposalInboxSection({required this.proposals, required this.repo});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'From partner',
              style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: proposals.length),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in proposals) _ProposalCard(proposal: p, repo: repo),
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

  const _ProposalCard({required this.proposal, required this.repo});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pColor = priorityColor(proposal.taskPriority);
    final catLabel =
        proposal.taskCategory.name[0].toUpperCase() +
        proposal.taskCategory.name.substring(1);

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
                  label: 'Accept',
                  color: kColorTeal,
                  onTap: () => repo.updateProposalStatus(
                    proposal.id,
                    ProposalStatus.accepted,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Snooze',
                  color: kColorWarmGrey,
                  onTap: () => repo.updateProposalStatus(
                    proposal.id,
                    ProposalStatus.snoozed,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Dismiss',
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

// ── Suggestion section ────────────────────────────────────────────────────────

class _SuggestionSection extends StatelessWidget {
  final List<PersonalTask> candidates;
  final String partnerDeviceId;
  final LoadSyncService loadSyncService;

  const _SuggestionSection({
    required this.candidates,
    required this.partnerDeviceId,
    required this.loadSyncService,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You could suggest',
          style: tt.titleSmall?.copyWith(color: kColorWarmGrey),
        ),
        const SizedBox(height: 2),
        Text(
          'Partner sees category \u0026 effort, not the task title.',
          style: tt.labelSmall?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 8),
        for (final task in candidates)
          _SuggestionCard(
            task: task,
            partnerDeviceId: partnerDeviceId,
            loadSyncService: loadSyncService,
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final PersonalTask task;
  final String partnerDeviceId;
  final LoadSyncService loadSyncService;

  const _SuggestionCard({
    required this.task,
    required this.partnerDeviceId,
    required this.loadSyncService,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _sent = false;

  void _propose() {
    final task = widget.task;
    final catLabel =
        task.category.name[0].toUpperCase() + task.category.name.substring(1);
    final priorityStr = priorityLabel(task.priority);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partner will see:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(categoryIcon(task.category)),
                title: Text('A $catLabel task'),
                subtitle: Text(
                  priorityStr.isNotEmpty
                      ? 'Priority: $priorityStr'
                      : 'No priority set',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        widget.loadSyncService.sendProposal(
                          toDeviceId: widget.partnerDeviceId,
                          task: task,
                        );
                        if (mounted) {
                          setState(() => _sent = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Proposal sent to partner'),
                            ),
                          );
                        }
                      },
                      child: const Text('Send proposal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final task = widget.task;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(categoryIcon(task.category), color: kColorWarmGrey),
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          task.category.name[0].toUpperCase() + task.category.name.substring(1),
          style: tt.labelSmall?.copyWith(color: kColorWarmGrey),
        ),
        trailing: _sent
            ? const Icon(
                Icons.check_circle_outline,
                color: kColorTeal,
                size: 20,
              )
            : TextButton(
                onPressed: _propose,
                child: const Text('Suggest \u2192'),
              ),
      ),
    );
  }
}
