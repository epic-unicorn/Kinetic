import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/mission_converter_service.dart';
import '../../todo/services/todo_repository.dart';
import 'convert_to_mission_sheet.dart';

// ---------------------------------------------------------------------------
// TaskDetailSheet
//
// Full-screen modal bottom sheet for creating or editing a PersonalTask.
// Pass task=null to create a new one.
// ---------------------------------------------------------------------------

class TaskDetailSheet extends StatefulWidget {
  final PersonalTask? task;
  final TodoRepository repo;
  final String? initialListId;
  final MissionConverterService? converter;

  const TaskDetailSheet({
    super.key,
    required this.repo,
    this.task,
    this.initialListId,
    this.converter,
  });

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _isAllDay = true;
  bool _isFlagged = false;
  bool _isPrivate = false;
  String? _recurrenceRule;
  String? _listId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
    _priority = t?.priority ?? TaskPriority.none;
    _dueDate = t?.dueDate;
    _isAllDay = t?.isAllDay ?? true;
    _isFlagged = t?.isFlagged ?? false;
    _isPrivate = t?.isPrivate ?? false;
    _recurrenceRule = t?.recurrenceRule;
    _listId = t?.listId ?? widget.initialListId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    if (widget.task == null) {
      await widget.repo.createTask(
        title: title,
        listId: _listId,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        isAllDay: _isAllDay,
        recurrenceRule: _recurrenceRule,
        isFlagged: _isFlagged,
        isPrivate: _isPrivate,
      );
    } else {
      await widget.repo.updateTask(
        widget.task!.copyWith(
          title: title,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          isAllDay: _isAllDay,
          recurrenceRule: _recurrenceRule,
          isFlagged: _isFlagged,
          isPrivate: _isPrivate,
          listId: _listId,
          clearDueDate: _dueDate == null,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kColorWarmGrey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Title ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleCtrl,
              autofocus: widget.task == null,
              style: tt.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Taaknaam',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
            ),
          ),

          // ── Notes ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _notesCtrl,
              style: tt.bodyMedium?.copyWith(color: kColorWarmGrey),
              decoration: const InputDecoration(
                hintText: 'Notities',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
            ),
          ),

          const Divider(height: 16),

          // ── Metadata rows ────────────────────────────────────────────────
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            label: _dueDate != null
                ? formatDueDate(_dueDate!, allDay: _isAllDay)
                : 'Vervaldatum toevoegen',
            active: _dueDate != null,
            onTap: () => _pickDate(),
            trailing: _dueDate != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _recurrenceRule = null;
                    }),
                  )
                : null,
          ),
          _MetaRow(
            icon: Icons.flag_outlined,
            label: _priority == TaskPriority.none
                ? 'Prioriteit'
                : 'Prioriteit: ${switch (_priority) {
                    TaskPriority.low => 'Laag',
                    TaskPriority.medium => 'Middel',
                    TaskPriority.high => 'Hoog',
                    TaskPriority.none => 'Geen',
                  }}',
            active: _priority != TaskPriority.none,
            color: _priority != TaskPriority.none
                ? priorityColor(_priority)
                : null,
            onTap: () => _pickPriority(context),
          ),
          _MetaRow(
            icon: _isFlagged ? Icons.flag : Icons.flag_outlined,
            label: 'Markeer',
            active: _isFlagged,
            color: _isFlagged ? kColorGold : null,
            onTap: () => setState(() => _isFlagged = !_isFlagged),
          ),
          _MetaRow(
            icon: _isPrivate ? Icons.lock : Icons.lock_open_outlined,
            label: _isPrivate ? 'Privé (niet voorgesteld)' : 'Privé',
            active: _isPrivate,
            onTap: () => setState(() => _isPrivate = !_isPrivate),
          ),
          if (_dueDate != null)
            _MetaRow(
              icon: Icons.repeat,
              label: _recurrenceRule ?? 'Herhalen',
              active: _recurrenceRule != null,
              onTap: () => _pickRecurrence(context),
            ),

          // ── Convert to Mission (only on existing tasks not yet linked) ────
          if (widget.task != null &&
              widget.task!.kidsTaskId == null &&
              widget.converter != null)
            _MetaRow(
              icon: Icons.bolt,
              label: 'Zet om naar opdracht',
              color: kColorGold,
              active: false,
              onTap: () => _openMissionSheet(context),
            )
          else if (widget.task != null && widget.task!.kidsTaskId != null)
            _MetaRow(
              icon: Icons.bolt,
              label: 'Opdracht aangemaakt ✓',
              color: kColorTeal,
              active: true,
              onTap: null,
            ),

          const SizedBox(height: 8),

          // ── Action bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(widget.task == null ? 'Toevoegen' : 'Opslaan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked == null || !mounted) return;
    // Always offer a time — cancelling the time picker keeps the date all-day.
    final time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: (!_isAllDay && _dueDate != null)
          ? TimeOfDay.fromDateTime(_dueDate!.toLocal())
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted) return;
    setState(() {
      if (time != null) {
        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        ).toUtc();
        _isAllDay = false;
      } else {
        _dueDate = DateTime(picked.year, picked.month, picked.day).toUtc();
        _isAllDay = true;
      }
    });
  }

  void _pickPriority(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in TaskPriority.values)
              ListTile(
                leading: Icon(
                  Icons.flag,
                  color: p == TaskPriority.none
                      ? kColorWarmGrey
                      : priorityColor(p),
                ),
                title: Text(switch (p) {
                  TaskPriority.none => 'Geen',
                  TaskPriority.low => 'Laag',
                  TaskPriority.medium => 'Middel',
                  TaskPriority.high => 'Hoog',
                }),
                trailing: _priority == p
                    ? const Icon(Icons.check, color: kColorTeal)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _priority = p);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openMissionSheet(BuildContext context) {
    Navigator.pop(context); // close this sheet first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ConvertToMissionSheet(
        task: widget.task!,
        converter: widget.converter!,
      ),
    );
  }

  void _pickRecurrence(BuildContext context) {
    // Simple recurrence picker — RRULE strings
    final options = <(String, String)>[
      ('Dagelijks', 'FREQ=DAILY'),
      ('Werkdagen', 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'),
      ('Wekelijks', 'FREQ=WEEKLY'),
      ('Tweewekelijks', 'FREQ=WEEKLY;INTERVAL=2'),
      ('Maandelijks', 'FREQ=MONTHLY'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Geen herhaling'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _recurrenceRule = null);
              },
            ),
            for (final (label, rule) in options)
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(label),
                trailing: _recurrenceRule == rule
                    ? const Icon(Icons.check, color: kColorTeal)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _recurrenceRule = rule);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MetaRow — a tappable information/action row in the detail sheet.
// ---------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active ? (color ?? kColorTeal) : kColorWarmGrey;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: effectiveColor),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: effectiveColor),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
