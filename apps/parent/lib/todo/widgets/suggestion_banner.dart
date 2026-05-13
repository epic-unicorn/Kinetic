import 'package:flutter/material.dart';

import '../../partner/services/partner_proposal_repository.dart';
import '../../todo/models/ai_suggestion.dart';
import '../../todo/models/enums.dart';
import '../../todo/services/ai_suggestion_repository.dart';
import '../../todo/services/todo_repository.dart';

// ---------------------------------------------------------------------------
// SuggestionBanner — shows one pending AI suggestion at a time.
//
// Shows a dismissable card at the top of the Tasks screen. The banner is
// hidden when there are no pending suggestions.
// ---------------------------------------------------------------------------

class SuggestionBanner extends StatelessWidget {
  final AiSuggestionRepository suggestionRepo;
  final TodoRepository todoRepo;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final bool partnerPaired;
  final String? activeListId;

  const SuggestionBanner({
    super.key,
    required this.suggestionRepo,
    required this.todoRepo,
    this.proposalRepo,
    this.myParentId,
    this.partnerPaired = false,
    this.activeListId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AiSuggestion>>(
      stream: suggestionRepo.watchPending(),
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final suggestion = suggestions.first;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _BannerCard(
            key: ValueKey(suggestion.id),
            suggestion: suggestion,
            suggestionRepo: suggestionRepo,
            todoRepo: todoRepo,
            proposalRepo: proposalRepo,
            myParentId: myParentId,
            partnerPaired: partnerPaired,
            activeListId: activeListId,
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final AiSuggestionRepository suggestionRepo;
  final TodoRepository todoRepo;
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final bool partnerPaired;
  final String? activeListId;

  const _BannerCard({
    super.key,
    required this.suggestion,
    required this.suggestionRepo,
    required this.todoRepo,
    this.proposalRepo,
    this.myParentId,
    required this.partnerPaired,
    this.activeListId,
  });

  String _reasonLabel(SuggestionReason r) => switch (r) {
    SuggestionReason.habit => 'Gewoonte',
    SuggestionReason.partnerComplement => 'Partner-aanvulling',
    SuggestionReason.seasonal => 'Seizoensgebonden',
    SuggestionReason.loadBalance => 'Taakverdeling',
  };

  Future<void> _accept(BuildContext context) async {
    await todoRepo.createTask(
      title: suggestion.title,
      notes: suggestion.notes,
      priority: TaskPriority.values[suggestion.priority],
      dueDate: suggestion.suggestedDueDate,
      listId: activeListId,
    );
    await suggestionRepo.accept(suggestion.id);
  }

  Future<void> _sendToPartner(BuildContext context) async {
    if (proposalRepo == null || myParentId == null) return;
    await proposalRepo!.createManualProposal(
      myParentId: myParentId!,
      taskTitle: suggestion.title,
      taskNotes: suggestion.notes,
      taskPriority: TaskPriority.values[suggestion.priority],
      taskDueDate: suggestion.suggestedDueDate,
    );
    await suggestionRepo.accept(suggestion.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voorstel naar partner gestuurd')),
      );
    }
  }

  Future<void> _dismiss() async {
    await suggestionRepo.dismiss(suggestion.id);
  }

  Future<void> _snooze() async {
    await suggestionRepo.snooze(suggestion.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Uitstellen'),
            content: const Text('Suggestie 7 dagen uitstellen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuleren'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Uitstellen'),
              ),
            ],
          ),
        );
        if (ok == true) await _snooze();
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        color: colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Chip(
                          label: Text(
                            _reasonLabel(suggestion.reason),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: colorScheme.secondaryContainer,
                          side: BorderSide(color: colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _ActionButton(
                          label: 'Toevoegen',
                          icon: Icons.add,
                          onPressed: () => _accept(context),
                          colorScheme: colorScheme,
                          filled: true,
                        ),
                        if (partnerPaired && proposalRepo != null)
                          _ActionButton(
                            label: '→ Partner',
                            icon: Icons.person_outline,
                            onPressed: () => _sendToPartner(context),
                            colorScheme: colorScheme,
                          ),
                        _ActionButton(
                          label: 'Sluiten',
                          icon: Icons.close,
                          onPressed: _dismiss,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          textStyle: const TextStyle(fontSize: 12),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
