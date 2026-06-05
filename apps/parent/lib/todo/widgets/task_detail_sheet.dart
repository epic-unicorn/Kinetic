import 'package:flutter/material.dart';

import '../../partner/services/partner_proposal_repository.dart';
import '../../settings/models/enrolled_kid.dart';
import '../../sync/webdav_config_repository.dart';
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
  final PartnerProposalRepository? proposalRepo;
  final String? myParentId;
  final String? initialListId;
  final String? initialTitle;
  final bool hasFamilyKey;
  final WebDavConfigRepository? configRepo;

  const TaskDetailSheet({
    super.key,
    required this.repo,
    this.task,
    this.proposalRepo,
    this.myParentId,
    this.initialListId,
    this.initialTitle,
    this.hasFamilyKey = false,
    this.configRepo,
  });

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _xpCtrl;

  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _isAllDay = true;
  String? _recurrenceRule;
  String? _listId;
  String? _customCategory;

  bool _saving = false;
  List<EnrolledKid> _enrolledKids = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(
      text: t?.title ?? widget.initialTitle ?? '',
    );
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
    _xpCtrl = TextEditingController(text: '${t?.xpReward ?? 10}');
    _priority = t?.priority ?? TaskPriority.none;
    _dueDate = t?.dueDate;
    _isAllDay = t?.isAllDay ?? true;
    _recurrenceRule = t?.recurrenceRule;
    _listId = t?.listId ?? widget.initialListId;
    _customCategory = t?.customCategory;
    _loadEnrolledKids();
  }

  Future<void> _loadEnrolledKids() async {
    if (widget.configRepo == null) return;
    try {
      final kids = await widget.configRepo!.loadEnrolledKids();
      if (mounted) setState(() => _enrolledKids = kids);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _xpCtrl.dispose();
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
          isPrivate: false,
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
            isPrivate: false,
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taak verwijderen?'),
        content: Text(
          '"${_titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : widget.task!.title}" wordt definitief verwijderd. Dit kan niet ongedaan worden gemaakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repo.deleteTask(widget.task!.id);
    if (mounted) Navigator.pop(context);
  }

  void _showSendDialog(BuildContext context) {
    final task = widget.task;
    if (task == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Taak doorsturen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (widget.proposalRepo != null)
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Stuur naar partner'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendToPartner(context);
                  },
                ),
              if (task.kidsTaskId != null)
                ListTile(
                  leading: Icon(Icons.bolt, color: kColorTeal),
                  title: const Text('Opdracht aangemaakt \u2713'),
                  enabled: false,
                )
              else if (_enrolledKids.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.bolt),
                  title: const Text('Stuur naar kinderen'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendToKids(context);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendToPartner(BuildContext context) async {
    final task = widget.task;
    if (task == null || widget.proposalRepo == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stuur naar partner?'),
        content: Text(
          '"${task.title}" wordt als voorstel naar je partner gestuurd en verdwijnt uit jouw lijst zodra zij/hij het accepteert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sturen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.proposalRepo!.createManualProposal(
      myParentId: widget.myParentId ?? '',
      taskTitle: task.title,
      taskNotes: task.notes,
      taskPriority: task.priority,
      taskDueDate: task.dueDate,
    );
    // Task stays in the sender's list until partner accepts the proposal.
    // When partner accepts, the sync orchestrator will detect the status change
    // and clean up the task automatically.
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendToKids(BuildContext context) async {
    final task = widget.task;
    if (task == null) return;

    // Use pre-loaded enrolled kids (already filtered to connected kids).
    final kids = _enrolledKids;
    if (kids.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen verbonden kinderen gevonden')),
        );
      }
      return;
    }

    EnrolledKid? selectedKid;
    if (kids.length > 1) {
      // Show kid picker dialog.
      selectedKid = await showDialog<EnrolledKid>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Stuur naar welk kind?'),
          children: [
            for (final kid in kids)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, kid),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.child_care, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        kid.name,
                        style: Theme.of(ctx).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Annuleren'),
              ),
            ),
          ],
        ),
      );
      if (selectedKid == null || !mounted) return;
    } else {
      selectedKid = kids.first;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stuur naar kinderen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedKid != null
                  ? '"${task.title}" wordt als opdracht naar ${selectedKid.name} gestuurd. De taak verdwijnt uit jouw lijst zodra het kind hem afrondt.'
                  : '"${task.title}" wordt als opdracht naar de kinderen gestuurd. De taak verdwijnt uit jouw lijst zodra een kind hem afrondt.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star_outline, size: 18),
                const SizedBox(width: 8),
                const Text('XP beloning:'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _xpCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sturen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repo.sendToKids(
      task.id,
      targetKidId: selectedKid.id,
      xpReward: int.tryParse(_xpCtrl.text.trim()) ?? 10,
    );
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
          // Herinnering row — combined date + time
          _MetaRow(
            icon: Icons.alarm_outlined,
            label: 'Herinnering',
            active: _dueDate != null,
            onTap: _dueDate != null ? null : () => _pickReminder(),
            titleWidget: _dueDate != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _pickDateOnly,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            _formatDateOnly(_dueDate!.toLocal()),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: kColorTeal,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _pickTimeOnly,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            _isAllDay
                                ? 'Tijd toevoegen'
                                : _formatTimeOnly(_dueDate!.toLocal()),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: kColorTeal,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
            trailing: _dueDate != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _isAllDay = true;
                      _recurrenceRule = null;
                    }),
                  )
                : null,
            leadingCheckbox: true,
            checked: _dueDate != null,
            onCheckChanged: (v) {
              if (v) {
                _setDefaultReminder();
              } else {
                setState(() {
                  _dueDate = null;
                  _isAllDay = true;
                  _recurrenceRule = null;
                });
              }
            },
          ),
          // Preset chips — only when no reminder is set
          if (_dueDate == null)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const SizedBox(width: 40),
              title: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('1 uur'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _applyReminderPreset(const Duration(hours: 1)),
                  ),
                  ActionChip(
                    label: const Text('Vanavond 20:00'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final now = DateTime.now();
                      _applyReminderAt(
                        DateTime(now.year, now.month, now.day, 20, 0),
                      );
                    },
                  ),
                  ActionChip(
                    label: const Text('Morgen 09:00'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final t = DateTime.now().add(const Duration(days: 1));
                      _applyReminderAt(DateTime(t.year, t.month, t.day, 9, 0));
                    },
                  ),
                  ActionChip(
                    label: const Text('Morgen 20:00'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final t = DateTime.now().add(const Duration(days: 1));
                      _applyReminderAt(DateTime(t.year, t.month, t.day, 20, 0));
                    },
                  ),
                ],
              ),
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

          const SizedBox(height: 8),

          // ── Action bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                if (widget.task != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Verwijderen',
                    onPressed: _saving ? null : () => _confirmDelete(context),
                  ),
                if (widget.hasFamilyKey && widget.task != null)
                  IconButton(
                    icon: const Icon(Icons.send_outlined),
                    tooltip: 'Doorsturen',
                    onPressed: _saving ? null : () => _showSendDialog(context),
                  ),
                const Spacer(),
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

  void _setDefaultReminder() {
    final now = DateTime.now();
    setState(() {
      _dueDate = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).toUtc();
      _isAllDay = false;
    });
  }

  void _applyReminderAt(DateTime when) {
    setState(() {
      _dueDate = when.toUtc();
      _isAllDay = false;
    });
  }

  Future<void> _pickDateOnly() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked == null || !mounted) return;
    final existing = _dueDate?.toLocal() ?? DateTime.now();
    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _isAllDay ? 0 : existing.hour,
        _isAllDay ? 0 : existing.minute,
      ).toUtc();
    });
  }

  Future<void> _pickTimeOnly() async {
    final current = _dueDate?.toLocal() ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final d = _dueDate?.toLocal() ?? DateTime.now();
    setState(() {
      _dueDate = DateTime(
        d.year,
        d.month,
        d.day,
        picked.hour,
        picked.minute,
      ).toUtc();
      _isAllDay = false;
    });
  }

  void _applyReminderPreset(Duration offset) {
    final target = DateTime.now().add(offset);
    setState(() {
      _dueDate = DateTime(
        target.year,
        target.month,
        target.day,
        target.hour,
        0,
      ).toUtc();
      _isAllDay = false;
    });
  }

  Future<void> _pickReminder() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (pickedDate == null || !mounted) return;
    final current = _dueDate?.toLocal() ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      initialTime: _isAllDay
          ? TimeOfDay.now()
          : TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ).toUtc();
      _isAllDay = false;
    });
  }

  String _formatDateOnly(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Vandaag';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day) {
      return 'Morgen';
    }
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  String _formatTimeOnly(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
  final Widget? titleWidget;
  final bool leadingCheckbox;
  final bool checked;
  final ValueChanged<bool>? onCheckChanged;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
    this.trailing,
    this.titleWidget,
    this.leadingCheckbox = false,
    this.checked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active
        ? (color ?? kColorTeal)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    if (leadingCheckbox) {
      return ListTile(
        dense: true,
        leading: GestureDetector(
          onTap: () => onCheckChanged?.call(!checked),
          child: Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: effectiveColor,
          ),
        ),
        title:
            titleWidget ??
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: effectiveColor),
            ),
        trailing: trailing,
        onTap: checked ? onTap : () => onCheckChanged?.call(true),
      );
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: effectiveColor),
      title:
          titleWidget ??
          Text(
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
