import 'package:flutter/material.dart';

import '../models/partner_proposal.dart';
import '../services/partner_load_repository.dart';
import '../services/partner_proposal_repository.dart';

/// PartnerScreen — task proposals and family workload coordination.
///
/// Shows proposals from the other parent with accept/snooze/dismiss actions,
/// plus family member workload metrics for fair task distribution.
class PartnerScreen extends StatefulWidget {
  final PartnerProposalRepository proposalRepository;
  final PartnerLoadRepository? loadRepository;

  const PartnerScreen({
    super.key,
    required this.proposalRepository,
    this.loadRepository,
  });

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  bool _showLoadMetrics = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner'),
        actions: [
          IconButton(
            icon: Icon(
              _showLoadMetrics ? Icons.assessment : Icons.assessment_outlined,
            ),
            onPressed: _toggleLoadMetrics,
            tooltip: 'Family workload metrics',
          ),
        ],
      ),
      body: _showLoadMetrics
          ? _buildLoadMetricsView(context)
          : _buildProposalsView(context),
    );
  }

  Widget _buildProposalsView(BuildContext context) {
    return StreamBuilder<List<PartnerProposal>>(
      stream: widget.proposalRepository.watchPending(),
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
                Text('Error loading proposals'),
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
                  'No proposals',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your partner hasn\'t suggested any tasks yet.',
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
          itemBuilder: (context, index) {
            final proposal = proposals[index];
            return _buildProposalCard(context, proposal);
          },
        );
      },
    );
  }

  Widget _buildProposalCard(BuildContext context, PartnerProposal proposal) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = _priorityColor(proposal.taskPriority, scheme);
    final dueSoon =
        proposal.taskDueDate != null &&
        proposal.taskDueDate!.isBefore(DateTime.now().add(Duration(days: 3)));

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
                Chip(
                  label: Text(proposal.taskCategory.name),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
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
                TextButton(
                  onPressed: () => _dismissProposal(proposal.id),
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _snoozeProposal(proposal.id),
                  child: const Text('Snooze'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                  onPressed: () => _acceptProposal(proposal.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMetricsView(BuildContext context) {
    if (widget.loadRepository == null) {
      return Center(
        child: Text(
          'Load metrics unavailable',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListenableBuilder(
      listenable: widget.loadRepository!,
      builder: (context, _) {
        final metrics = widget.loadRepository!.familyLoad;

        if (metrics.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.scale_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No family data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: metrics.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _buildLoadMetricCard(context, metric);
          },
        );
      },
    );
  }

  Widget _buildLoadMetricCard(
    BuildContext context,
    dynamic metric, // FamilyLoadMetrics
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metric.parentName ?? 'Unknown Parent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${metric.taskCount} tasks',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${metric.urgentCount}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: scheme.error),
                      ),
                      Text(
                        'Urgent',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${(metric.tasksByCategory?.length ?? 0)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: scheme.primary),
                      ),
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((metric.tasksByCategory?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Text(
                'By Category',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (metric.tasksByCategory?.entries ?? [])
                    .map(
                      (e) => Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleLoadMetrics() {
    setState(() => _showLoadMetrics = !_showLoadMetrics);
    if (_showLoadMetrics && widget.loadRepository != null) {
      widget.loadRepository!.refreshFamilyLoad();
    }
  }

  Future<void> _acceptProposal(String proposalId) async {
    await widget.proposalRepository.accept(proposalId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proposal accepted')));
    }
  }

  Future<void> _snoozeProposal(String proposalId) async {
    await widget.proposalRepository.snooze(proposalId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proposal snoozed')));
    }
  }

  Future<void> _dismissProposal(String proposalId) async {
    await widget.proposalRepository.dismiss(proposalId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proposal dismissed')));
    }
  }

  Color _priorityColor(dynamic priority, ColorScheme scheme) {
    final name = priority.name.toString();
    if (name.contains('high') || name.contains('urgent')) {
      return scheme.error;
    } else if (name.contains('medium') || name.contains('normal')) {
      return scheme.primary;
    } else {
      return scheme.outline;
    }
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    return '${date.month}/${date.day}';
  }
}
