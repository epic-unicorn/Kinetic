import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import 'category_sheet.dart';

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
  final bool hasFamilyKey;

  const TaskDetailSheet({
    super.key,
    required this.repo,
    this.task,
    this.initialListId,
    this.hasFamilyKey = false,
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
  bool _isPrivate = false;
  String? _recurrenceRule;
  String? _listId;
  String? _customCategory;

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
    _isPrivate = t?.isPrivate ?? false;
    _recurrenceRule = t?.recurrenceRule;
    _listId = t?.listId ?? widget.initialListId;
    _customCategory = t?.customCategory;
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

    try {
      final newNotes = _notesCtrl.text.trim();
      if (widget.task == null) {
        await widget.repo.createTask(
          title: title,
          listId: _listId,
          notes: newNotes.isEmpty ? null : newNotes,
          priority: _priority,
          dueDate: _dueDate,
          isAllDay: _isAllDay,
          recurrenceRule: _recurrenceRule,
          isPrivate: _isPrivate,
          customCategory: _customCategory,
        );
      } else {
        await widget.repo.updateTask(
          widget.task!.copyWith(
            title: title,
            notes: newNotes.isEmpty ? null : newNotes,
            clearNotes: newNotes.isEmpty,
            priority: _priority,
            dueDate: _dueDate,
            isAllDay: _isAllDay,
            recurrenceRule: _recurrenceRule,
            isPrivate: _isPrivate,
            listId: _listId,
            customCategory: _customCategory,
            clearCustomCategory: _customCategory == null,
            clearDueDate: _dueDate == null,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
      }
    }
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
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withAlpha(80),
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
              decoration: InputDecoration(
                hintText: 'Taaknaam',
                hintStyle: tt.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              style: tt.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Notities',
                hintStyle: tt.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
            icon: _isPrivate ? Icons.lock : Icons.lock_open_outlined,
            label: _isPrivate ? 'Privé (niet voorgesteld)' : 'Privé',
            active: _isPrivate,
            onTap: () => setState(() => _isPrivate = !_isPrivate),
          ),
          _MetaRow(
            icon: Icons.label_outline,
            label: _customCategory ?? 'Categorie toevoegen',
            active: _customCategory != null,
            onTap: () => _pickCategory(context),
            trailing: _customCategory != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _customCategory = null),
                  )
                : null,
          ),
          if (_dueDate != null)
            _MetaRow(
              icon: Icons.repeat,
              label: _recurrenceRule ?? 'Herhalen',
              active: _recurrenceRule != null,
              onTap: () => _pickRecurrence(context),
            ),

          // ── Send to Kids — only visible when connected to a family ─────────
          if (widget.hasFamilyKey && widget.task != null)
            if (widget.task!.kidsTaskId != null)
              const _MetaRow(
                icon: Icons.bolt,
                label: 'Opdracht aangemaakt ✓',
                color: kColorTeal,
                active: true,
                onTap: null,
              )
            else
              const _MetaRow(
                icon: Icons.bolt,
                label: 'Stuur naar kinderen (binnenkort)',
                active: false,
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

  Future<void> _pickCategory(BuildContext context) async {
    final categories = await widget.repo.watchTaskCategories().first;
    if (!mounted) return;
    final result = await showCategoryPicker(
      // ignore: use_build_context_synchronously
      context: context,
      existingCategories: categories,
      currentCategory: _customCategory,
    );
    if (result != null && mounted) {
      setState(() => _customCategory = result.isEmpty ? null : result);
    }
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
                      ? Theme.of(context).colorScheme.outlineVariant
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
    final effectiveColor = active
        ? (color ?? kColorTeal)
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
