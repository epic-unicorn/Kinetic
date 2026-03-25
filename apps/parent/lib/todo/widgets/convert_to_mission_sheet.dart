import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/personal_task.dart';
import '../services/mission_converter_service.dart';

// ---------------------------------------------------------------------------
// ConvertToMissionSheet
//
// Bottom sheet that lets a parent convert a PersonalTask into a kids mission.
// Shows:
//   • XP reward slider (5 – 100 in steps of 5)
//   • Optional child assignment (populated from MissionConverterService)
//   • Privacy note: only shown when the task is currently private
// ---------------------------------------------------------------------------

class ConvertToMissionSheet extends StatefulWidget {
  final PersonalTask task;
  final MissionConverterService converter;

  const ConvertToMissionSheet({
    super.key,
    required this.task,
    required this.converter,
  });

  @override
  State<ConvertToMissionSheet> createState() => _ConvertToMissionSheetState();
}

class _ConvertToMissionSheetState extends State<ConvertToMissionSheet> {
  int _xp = 20;
  String? _selectedChildId;
  bool _converting = false;

  late final List<({String id, String name})> _children;

  @override
  void initState() {
    super.initState();
    _children = widget.converter.availableChildren;
  }

  Future<void> _convert() async {
    setState(() => _converting = true);
    await widget.converter.convertToMission(
      widget.task,
      xpReward: _xp,
      assignToChildId: _selectedChildId,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt, color: kColorGold, size: 18),
            const SizedBox(width: 8),
            Text('"${widget.task.title}" → Opdracht ($_xp XP)'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.bolt, color: kColorGold),
                  const SizedBox(width: 8),
                  Text('Zet om naar opdracht', style: tt.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '"${widget.task.title}"',
                style: tt.bodySmall?.copyWith(color: kColorWarmGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              // ── XP Slider ────────────────────────────────────────────────
              Row(
                children: [
                  Text('XP beloning', style: tt.labelMedium),
                  const Spacer(),
                  _XpBadge(xp: _xp),
                ],
              ),
              Slider(
                value: _xp.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                activeColor: kColorTeal,
                label: '$_xp XP',
                onChanged: (v) => setState(() => _xp = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '5',
                    style: tt.labelSmall?.copyWith(color: Colors.white38),
                  ),
                  Text(
                    '100',
                    style: tt.labelSmall?.copyWith(color: Colors.white38),
                  ),
                ],
              ),

              // ── Child assignment ─────────────────────────────────────────
              if (_children.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Toewijzen aan', style: tt.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _ChildChip(
                      label: 'Iedereen',
                      selected: _selectedChildId == null,
                      onTap: () => setState(() => _selectedChildId = null),
                    ),
                    for (final child in _children)
                      _ChildChip(
                        label: child.name,
                        selected: _selectedChildId == child.id,
                        onTap: () =>
                            setState(() => _selectedChildId = child.id),
                      ),
                  ],
                ),
              ],

              // ── Privacy note ─────────────────────────────────────────────
              if (widget.task.isPrivate) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: kColorWarmGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deze taak is als privé gemarkeerd. De opdracht is wel zichtbaar voor kinderen op hun apparaten.',
                        style: tt.labelSmall?.copyWith(color: kColorWarmGrey),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // ── Action row ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _converting ? null : _convert,
                      icon: _converting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt),
                      label: Text(
                        _converting ? 'Aanmaken…' : 'Opdracht aanmaken',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _converting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Annuleren'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _XpBadge extends StatelessWidget {
  final int xp;
  const _XpBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kColorGold.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorGold.withAlpha(100)),
      ),
      child: Text(
        '$xp XP',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: kColorGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ChildChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChildChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kColorTeal.withAlpha(50) : Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? kColorTeal : Colors.white24),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? kColorTeal : kColorWarmGrey,
          ),
        ),
      ),
    );
  }
}
