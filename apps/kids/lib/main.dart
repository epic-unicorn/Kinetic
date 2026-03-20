import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_kiosk/kinetic_kiosk.dart';
import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import 'secure/flutter_secure_key_value_store.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KineticKidsApp());
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------

class KineticKidsApp extends StatelessWidget {
  const KineticKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetic Kids',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
        ),
      ),
      home: const _KidsShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell — owns all shared services; rebuilds on kiosk status changes.
// ---------------------------------------------------------------------------

class _KidsShell extends StatefulWidget {
  const _KidsShell();

  @override
  State<_KidsShell> createState() => _KidsShellState();
}

class _KidsShellState extends State<_KidsShell> {
  late final IdentityService _identityService;
  late final CouchSyncService _syncService;
  late final SyncOrchestrator _syncOrchestrator;
  late final ApprovalService _approvalService;
  late final TicketService _ticketService;
  late final AndroidKioskService _kioskService;

  DeviceIdentity? _identity;
  KioskState _kioskState = const KioskState.unlocked();

  @override
  void initState() {
    super.initState();
    _identityService = IdentityService(store: FlutterSecureKeyValueStore());
    _syncService = CouchSyncService();
    _syncOrchestrator = SyncOrchestrator(
      discoveryService: BonsoirMdnsDiscoveryService(),
      syncService: _syncService,
      meshKey: List<int>.filled(32, 0), // placeholder — replaced in Phase 5
    );
    _syncOrchestrator.start();

    final store = _SyncDocumentStore(_syncService);
    _approvalService = ApprovalService(store: store);
    _ticketService = TicketService(store: store);

    _kioskService = AndroidKioskService();
    _kioskService.initialize();
    _kioskService.stateStream.listen((s) => setState(() => _kioskState = s));

    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final id = await _identityService.getOrCreateIdentity();
    if (mounted) setState(() => _identity = id);
  }

  @override
  void dispose() {
    _syncOrchestrator.dispose();
    _kioskService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_identity == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return KidsHomeScreen(
      identity: _identity!,
      approvalService: _approvalService,
      ticketService: _ticketService,
      kioskService: _kioskService,
      kioskState: _kioskState,
      syncService: _syncService,
    );
  }
}

// ---------------------------------------------------------------------------
// DocumentStore adapter — bridges CouchSyncService ↔ DocumentStore interface
// ---------------------------------------------------------------------------

class _SyncDocumentStore implements DocumentStore {
  final CouchSyncService _sync;
  _SyncDocumentStore(this._sync);

  @override
  void upsert(Map<String, dynamic> doc) => _sync.upsertLocal(doc);

  @override
  List<Map<String, dynamic>> get all => _sync.localDocs;
}

// ---------------------------------------------------------------------------
// Home Screen
// ---------------------------------------------------------------------------

class KidsHomeScreen extends StatefulWidget {
  final DeviceIdentity identity;
  final ApprovalService approvalService;
  final TicketService ticketService;
  final KioskService kioskService;
  final KioskState kioskState;
  final CouchSyncService syncService;

  const KidsHomeScreen({
    super.key,
    required this.identity,
    required this.approvalService,
    required this.ticketService,
    required this.kioskService,
    required this.kioskState,
    required this.syncService,
  });

  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen> {
  void _refresh() => setState(() {});

  List<Task> get _myTasks => widget.syncService.localDocs
      .where(
        (d) =>
            d['assignedToId'] == widget.identity.deviceId &&
            d['status'] != TaskStatus.completed.name,
      )
      .map((d) => Task.fromJson(d))
      .toList();

  @override
  Widget build(BuildContext context) {
    final ledgerDoc = widget.syncService.localDocs
        .where((d) => d['_id'] == 'xp:${widget.identity.deviceId}')
        .firstOrNull;
    final xpBalance = ledgerDoc == null
        ? 0
        : XpLedger.fromJson(ledgerDoc).balance;
    final tasks = _myTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Missions'),
        centerTitle: true,
        actions: [
          _KioskLockButton(
            kioskService: widget.kioskService,
            kioskState: widget.kioskState,
          ),
        ],
      ),
      body: Column(
        children: [
          _XpHeader(balance: xpBalance),
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyMissions()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (ctx, i) => _TaskCard(
                      task: tasks[i],
                      syncService: widget.syncService,
                      onChanged: _refresh,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.help_outline),
        label: const Text('Ask for help'),
        onPressed: () => _showHelpDialog(context),
      ),
    );
  }

  Future<void> _showHelpDialog(BuildContext context) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _HelpTicketDialog(
        familyPlanId: 'plan:main',
        requesterId: widget.identity.deviceId,
        ticketService: widget.ticketService,
      ),
    );
    if (submitted == true) _refresh();
  }
}

// ---------------------------------------------------------------------------
// XP Header
// ---------------------------------------------------------------------------

class _XpHeader extends StatelessWidget {
  final int balance;
  const _XpHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          Text(
            '$balance XP',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyMissions extends StatelessWidget {
  const _EmptyMissions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration, size: 64, color: Colors.amber),
          SizedBox(height: 16),
          Text(
            'All done! No missions right now.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task Card — mission with Submit action → pendingApproval
// ---------------------------------------------------------------------------

class _TaskCard extends StatelessWidget {
  final Task task;
  final CouchSyncService syncService;
  final VoidCallback onChanged;

  const _TaskCard({
    required this.task,
    required this.syncService,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _statusIcon(task.status),
        title: Text(task.title),
        subtitle: task.xpReward > 0
            ? Text(
                '+${task.xpReward} XP',
                style: const TextStyle(color: Colors.amber),
              )
            : null,
        trailing: _actionButton(),
      ),
    );
  }

  Widget _statusIcon(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => const Icon(Icons.radio_button_unchecked),
      TaskStatus.inProgress => const Icon(Icons.pending, color: Colors.blue),
      TaskStatus.pendingApproval => const Icon(
        Icons.hourglass_top,
        color: Colors.orange,
      ),
      TaskStatus.completed => const Icon(
        Icons.check_circle,
        color: Colors.green,
      ),
    };
  }

  Widget? _actionButton() {
    if (task.status == TaskStatus.pendingApproval) {
      return const Chip(label: Text('Waiting…'));
    }
    if (task.status == TaskStatus.pending ||
        task.status == TaskStatus.inProgress) {
      final isHabit = task.category == TaskCategory.habit;
      return FilledButton.tonal(
        onPressed: _handleSubmit,
        child: Text(isHabit ? 'Done' : 'Submit'),
      );
    }
    return null;
  }

  void _handleSubmit() {
    final newStatus = task.category == TaskCategory.habit
        ? TaskStatus
              .completed // habits complete instantly
        : TaskStatus.pendingApproval; // missions wait for parent approval
    final updated = task.copyWith(status: newStatus);
    syncService.upsertLocal({'_id': updated.id, ...updated.toJson()});
    onChanged();
  }
}

// ---------------------------------------------------------------------------
// Kiosk lock/unlock button in the AppBar
// ---------------------------------------------------------------------------

class _KioskLockButton extends StatelessWidget {
  final KioskService kioskService;
  final KioskState kioskState;

  const _KioskLockButton({
    required this.kioskService,
    required this.kioskState,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = kioskState.isLocked;
    return IconButton(
      tooltip: isLocked ? 'Exit kiosk mode' : 'Enter kiosk mode',
      icon: Icon(
        isLocked ? Icons.lock : Icons.lock_open,
        color: isLocked ? Colors.amber : Colors.white38,
      ),
      onPressed: () async {
        if (isLocked) {
          await kioskService.unlock();
        } else {
          await kioskService.lock();
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Help-ticket dialog
// ---------------------------------------------------------------------------

class _HelpTicketDialog extends StatefulWidget {
  final String familyPlanId;
  final String requesterId;
  final TicketService ticketService;

  const _HelpTicketDialog({
    required this.familyPlanId,
    required this.requesterId,
    required this.ticketService,
  });

  @override
  State<_HelpTicketDialog> createState() => _HelpTicketDialogState();
}

class _HelpTicketDialogState extends State<_HelpTicketDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask for help'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'What do you need help with?',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'More details (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.ticketService.createTicket(
      familyPlanId: widget.familyPlanId,
      requesterId: widget.requesterId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    Navigator.pop(context, true);
  }
}
