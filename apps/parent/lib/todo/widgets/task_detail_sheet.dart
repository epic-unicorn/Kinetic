import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../../family/family_connection_service.dart';
import '../../partner/services/partner_proposal_repository.dart';
import '../../settings/models/enrolled_kid.dart';
import '../../sync/webdav_config_repository.dart';
import '../../theme/app_theme.dart';
import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/reminder_proposal_engine.dart';
import '../../todo/services/todo_repository.dart';
import 'category_sheet.dart';
import 'detail_meta_row.dart';

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
  final bool partnerPaired;
  final WebDavConfigRepository? configRepo;
  final Future<List<PresenceInfo>> Function()? pullPresence;

  const TaskDetailSheet({
    super.key,
    required this.repo,
    this.task,
    this.proposalRepo,
    this.myParentId,
    this.initialListId,
    this.initialTitle,
    this.hasFamilyKey = false,
    this.partnerPaired = false,
    this.configRepo,
    this.pullPresence,
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
  List<ReminderChipProposal> _reminderChips = [];
  List<PersonalTask> _completedTasks = [];
  FamilyMemberStatus? _partnerStatus;
  List<FamilyMemberStatus> _kidStatuses = [];
  Timer? _chipDebounce;
  final _reminderEngine = ReminderProposalEngine();

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
    _titleCtrl.addListener(_onTitleChanged);
    _loadEnrolledKids();
    _loadCompletedTasks();
    _loadFamilyConnections();
    _refreshReminderChips();
  }

  void _onTitleChanged() {
    _chipDebounce?.cancel();
    _chipDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshReminderChips();
    });
  }

  Future<void> _loadCompletedTasks() async {
    try {
      final tasks = await widget.repo.watchCompletedTasks().first;
      if (mounted) {
        setState(() => _completedTasks = tasks);
        _refreshReminderChips();
      }
    } catch (_) {}
  }

  Future<void> _loadFamilyConnections() async {
    if (widget.configRepo == null) return;
    try {
      final presence = widget.pullPresence != null
          ? await widget.pullPresence!()
          : <PresenceInfo>[];
      final partnerPaired = await widget.configRepo!.isPartnerPaired();
      if (!mounted) return;
      final allowWithoutPresence = widget.pullPresence == null;
      setState(() {
        _partnerStatus = FamilyConnectionService.partnerStatus(
          partnerPaired: partnerPaired,
          presenceList: presence,
          allowWithoutPresence: allowWithoutPresence,
        );
        _kidStatuses = FamilyConnectionService.kidStatuses(
          enrolledKids: _enrolledKids,
          presenceList: presence,
          allowWithoutPresence: allowWithoutPresence,
        );
      });
    } catch (_) {}
  }

  void _refreshReminderChips() {
    final chips = _reminderEngine.propose(
      title: _titleCtrl.text,
      category: widget.task?.category,
      completedTasks: _completedTasks,
    );
    setState(() => _reminderChips = chips);
  }

  Future<void> _loadEnrolledKids() async {
    if (widget.configRepo == null) return;
    try {
      final kids = await widget.configRepo!.loadEnrolledKids();
      if (mounted) {
        setState(() => _enrolledKids = kids);
        await _loadFamilyConnections();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _chipDebounce?.cancel();
    _titleCtrl.removeListener(_onTitleChanged);
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

  bool get _canSend =>
      FamilyConnectionService.canSend(
        partner: _partnerStatus,
        kids: _kidStatuses,
      );

  void _showSendDialog(BuildContext context) {
    final task = widget.task;
    if (task == null) return;

    if (!_canSend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geen verbonden partner of kinderen'),
        ),
      );
      return;
    }

    FamilyMemberStatus? selectedPartner;
    FamilyMemberStatus? selectedKid;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Taak doorsturen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (task.kidsTaskId != null)
                  const ListTile(
                    leading: Icon(Icons.bolt, color: kColorTeal),
                    title: Text('Opdracht aangemaakt \u2713'),
                    enabled: false,
                  )
                else ...[
                  if (_partnerStatus != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        'Partner',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.people_outline,
                        color: _partnerStatus!.isConnected
                            ? null
                            : Theme.of(context).disabledColor,
                      ),
                      title: Text(_partnerStatus!.name),
                      subtitle: Text(_partnerStatus!.statusLabel),
                      enabled: _partnerStatus!.isConnected,
                      selected: selectedPartner != null,
                      onTap: _partnerStatus!.isConnected
                          ? () => setSheetState(() {
                              selectedPartner = _partnerStatus;
                              selectedKid = null;
                            })
                          : null,
                    ),
                  ],
                  if (_kidStatuses.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        'Kinderen',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    for (final kid in _kidStatuses)
                      ListTile(
                        leading: Icon(
                          Icons.child_care,
                          color: kid.isConnected
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
                        title: Text(kid.name),
                        subtitle: Text(kid.statusLabel),
                        enabled: kid.isConnected,
                        selected: selectedKid?.id == kid.id,
                        onTap: kid.isConnected
                            ? () => setSheetState(() {
                                selectedKid = kid;
                                selectedPartner = null;
                              })
                            : null,
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuleren'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              (selectedPartner != null || selectedKid != null)
                              ? () {
                                  Navigator.pop(ctx);
                                  if (selectedPartner != null) {
                                    _sendToPartner(context);
                                  } else if (selectedKid != null) {
                                    _sendToKids(context, selectedKid!);
                                  }
                                }
                              : null,
                          child: const Text('Sturen'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendToPartner(BuildContext context) async {
    final task = widget.task;
    if (task == null || widget.proposalRepo == null) return;
    if (_partnerStatus?.isConnected != true) return;

    if (_partnerStatus!.isStale && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verbinding verouderd'),
          content: Text(
            'Je partner is voor het laatst gezien ${_partnerStatus!.statusLabel.toLowerCase()}. '
            'Toch sturen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Toch sturen'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

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

  Future<void> _sendToKids(
    BuildContext context,
    FamilyMemberStatus selectedKid,
  ) async {
    final task = widget.task;
    if (task == null) return;
    if (!selectedKid.isConnected) return;

    if (selectedKid.isStale && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verbinding verouderd'),
          content: Text(
            '${selectedKid.name} is voor het laatst gezien '
            '${selectedKid.statusLabel.toLowerCase()}. Toch sturen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Toch sturen'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final enrolledKid = _enrolledKids.firstWhere(
      (k) => k.id == selectedKid.id,
      orElse: () => EnrolledKid(
        id: selectedKid.id,
        name: selectedKid.name,
        enrolledAt: DateTime.now(),
      ),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stuur naar ${enrolledKid.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${task.title}" wordt als opdracht naar ${enrolledKid.name} gestuurd. '
              'De taak verdwijnt uit jouw lijst zodra het kind hem afrondt.',
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
      targetKidId: enrolledKid.id,
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
          DetailMetaRow(
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
          // Smart reminder chips — only when no reminder is set
          if (_dueDate == null)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const SizedBox(width: 40),
              title: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _reminderChips.length; i++)
                    Tooltip(
                      message: _reminderChips[i].explanation ?? '',
                      child: ActionChip(
                        avatar: i == 0
                            ? Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: i == 0 ? kColorTeal : null,
                              )
                            : null,
                        label: Text(_reminderChips[i].label),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _applyReminderAt(_reminderChips[i].at),
                      ),
                    ),
                ],
              ),
            ),
          DetailMetaRow(
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
          DetailMetaRow(
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
            DetailMetaRow(
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
                    tooltip: _canSend
                        ? 'Doorsturen'
                        : 'Geen verbonden partner of kinderen',
                    onPressed: _saving || !_canSend
                        ? null
                        : () => _showSendDialog(context),
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
