import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'secure/flutter_secure_key_value_store.dart';
import 'support/couch_document_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KineticParentApp());
}

class KineticParentApp extends StatelessWidget {
  const KineticParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetic Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C6FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const _RootShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Root Shell — bottom-nav scaffold shared by all top-level screens.
// ---------------------------------------------------------------------------

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  late final IdentityService _identityService;
  late final PairingService _pairingService;
  late final CouchSyncService _syncService;
  late final SyncOrchestrator _syncOrchestrator;
  late final ApprovalService _approvalService;
  late final TicketService _ticketService;

  int _selectedIndex = 0;
  SyncStatus _syncStatus = SyncStatus.idle();

  @override
  void initState() {
    super.initState();
    _identityService = IdentityService(store: FlutterSecureKeyValueStore());
    _pairingService = PairingService(identityService: _identityService);
    _syncService = CouchSyncService();
    _syncOrchestrator = SyncOrchestrator(
      discoveryService: BonsoirMdnsDiscoveryService(),
      syncService: _syncService,
      meshKey: List<int>.filled(32, 0), // placeholder until FamilyPlan exists
    );
    _syncOrchestrator.statusStream.listen(
      (s) => setState(() => _syncStatus = s),
    );
    _syncOrchestrator.start();

    final store = CouchDocumentStore(_syncService);
    _approvalService = ApprovalService(store: store);
    _ticketService = TicketService(store: store);
  }

  @override
  void dispose() {
    _syncOrchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PairingScreen(
        identityService: _identityService,
        pairingService: _pairingService,
        syncStatus: _syncStatus,
      ),
      ApprovalsScreen(
        approvalService: _approvalService,
        ticketService: _ticketService,
        syncStatus: _syncStatus,
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.qr_code), label: 'Pair'),
          NavigationDestination(
            icon: _PendingBadge(count: _approvalService.pendingTasks.length),
            label: 'Approvals',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pairing Screen — Phase 1 entry point
// ---------------------------------------------------------------------------

class PairingScreen extends StatefulWidget {
  final IdentityService identityService;
  final PairingService pairingService;
  final SyncStatus syncStatus;

  const PairingScreen({
    super.key,
    required this.identityService,
    required this.pairingService,
    required this.syncStatus,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  DeviceIdentity? _identity;
  String? _qrPayload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final identity = await widget.identityService.getOrCreateIdentity();
    final qr = await widget.pairingService.generatePairingPayload(
      deviceLabel: 'Parent Phone',
      role: MemberRole.parent,
    );
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _qrPayload = qr;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final shortId = _identity!.deviceId.substring(0, 8).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Kinetic Link'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Pair a second device',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Show this QR to the other device to join the family mesh.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _qrPayload!,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _DeviceBadge(shortId: shortId),
              const Spacer(),
              _SyncBanner(status: widget.syncStatus),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Regenerate QR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceBadge extends StatelessWidget {
  final String shortId;
  const _DeviceBadge({required this.shortId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fingerprint, size: 16),
          const SizedBox(width: 8),
          Text(
            'Device  $shortId\u2026',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final SyncStatus status;
  const _SyncBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status.state) {
      SyncState.idle when status.lastResult != null => (
        Icons.check_circle_outline,
        'Synced ↑${status.lastResult!.pushed} ↓${status.lastResult!.pulled}',
        Colors.greenAccent,
      ),
      SyncState.syncing => (
        Icons.sync,
        'Syncing with ${status.peer?.deviceId.substring(0, 8) ?? '…'}',
        Colors.blueAccent,
      ),
      SyncState.error => (
        Icons.error_outline,
        status.errorMessage ?? 'Sync error',
        Colors.redAccent,
      ),
      _ => (Icons.cloud_off, 'Waiting for home server…', Colors.white38),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badge shown on the Approvals tab when tasks are pending.
// ---------------------------------------------------------------------------

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Icon(Icons.check_circle_outline);
    return Badge(
      label: Text('$count'),
      child: const Icon(Icons.pending_actions),
    );
  }
}

// ---------------------------------------------------------------------------
// Approvals Screen — Phase 3 task approval + help-ticket inbox.
// ---------------------------------------------------------------------------

class ApprovalsScreen extends StatefulWidget {
  final ApprovalService approvalService;
  final TicketService ticketService;
  final SyncStatus syncStatus;

  const ApprovalsScreen({
    super.key,
    required this.approvalService,
    required this.ticketService,
    required this.syncStatus,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  // Refresh after approve/reject actions.
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pendingTasks = widget.approvalService.pendingTasks;
    final openTickets = widget.ticketService.openTickets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals & Help'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SyncBanner(status: widget.syncStatus),
          ),
        ),
      ),
      body: pendingTasks.isEmpty && openTickets.isEmpty
          ? const _EmptyInbox()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pendingTasks.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Proof submissions (${pendingTasks.length})',
                  ),
                  ...pendingTasks.map(
                    (task) => _TaskApprovalCard(
                      task: task,
                      approvalService: widget.approvalService,
                      onDone: _refresh,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (openTickets.isNotEmpty) ...[
                  _SectionHeader(label: 'Help tickets (${openTickets.length})'),
                  ...openTickets.map(
                    (ticket) => _TicketCard(
                      ticket: ticket,
                      ticketService: widget.ticketService,
                      onDone: _refresh,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'All clear — nothing to approve.',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white60),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task proof-submission card with Approve / Reject actions.
// ---------------------------------------------------------------------------

class _TaskApprovalCard extends StatelessWidget {
  final Task task;
  final ApprovalService approvalService;
  final VoidCallback onDone;

  const _TaskApprovalCard({
    required this.task,
    required this.approvalService,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Colors.amber),
        title: Text(task.title),
        subtitle: Text(
          '${task.xpReward} XP · ${task.assignedToId?.substring(0, 8) ?? '?'}…',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              onPressed: () {
                approvalService.approveTask(
                  task: task,
                  approverId:
                      'parent', // replaced with real identity in Phase 5
                );
                onDone();
              },
            ),
            IconButton(
              tooltip: 'Reject',
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
              onPressed: () {
                approvalService.rejectTask(task: task, approverId: 'parent');
                onDone();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help-ticket card with Resolve action.
// ---------------------------------------------------------------------------

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final TicketService ticketService;
  final VoidCallback onDone;

  const _TicketCard({
    required this.ticket,
    required this.ticketService,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.help_outline, color: Colors.blueAccent),
        title: Text(ticket.title),
        subtitle: Text(
          ticket.description ?? 'No description',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: TextButton(
          child: const Text('Resolve'),
          onPressed: () {
            ticketService.updateStatus(
              ticket.id,
              status: TicketStatus.resolved,
              resolvedById: 'parent',
              resolution: 'Resolved by parent',
            );
            onDone();
          },
        ),
      ),
    );
  }
}
