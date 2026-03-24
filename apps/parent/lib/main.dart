import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import 'db/app_database.dart';
import 'partner/screens/partner_screen.dart';
import 'partner/services/load_sync_service.dart';
import 'secure/flutter_secure_key_value_store.dart';
import 'settings/settings_screen.dart';
import 'support/couch_document_store.dart';
import 'todo/screens/tasks_screen.dart';
import 'todo/services/mission_converter_service.dart';
import 'todo/services/todo_repository.dart';

// ---------------------------------------------------------------------------
// Hub configuration — supply at build time via --dart-define, e.g.:
//   flutter build apk \
//     --dart-define=MESH_KEY_HEX=<64-char-hex> \
//     --dart-define=COUCH_USER=kinetic \
//     --dart-define=COUCH_PASSWORD=changeme
//
// The defaults below match hub/.env.example for local development.
// ---------------------------------------------------------------------------

const _kMeshKeyHex = String.fromEnvironment(
  'MESH_KEY_HEX',
  // dev-only fallback — replace in production via --dart-define
  defaultValue:
      'dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0',
);
const _kCouchUser = String.fromEnvironment(
  'COUCH_USER',
  defaultValue: 'kinetic',
);
const _kCouchPassword = String.fromEnvironment(
  'COUCH_PASSWORD',
  defaultValue: 'changeme',
);

List<int> _parseMeshKey() => List.generate(
  32,
  (i) => int.parse(_kMeshKeyHex.substring(i * 2, i * 2 + 2), radix: 16),
);

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
          seedColor: const Color(0xFF44BBA4),
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
  late final AppDatabase _db;
  late final TodoRepository _todoRepository;
  late final LoadSyncService _loadSyncService;
  late final CouchDocumentStore _store;
  late final MissionConverterService _missionConverter;

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
      meshKey: _parseMeshKey(),
      credentials: (username: _kCouchUser, password: _kCouchPassword),
    );
    _syncOrchestrator.statusStream.listen(
      (s) => setState(() => _syncStatus = s),
    );
    _syncOrchestrator.start();

    final store = CouchDocumentStore(_syncService);
    _store = store;
    _approvalService = ApprovalService(store: store);
    _ticketService = TicketService(store: store);

    _db = AppDatabase();
    _todoRepository = TodoRepository(db: _db);
    _loadSyncService = LoadSyncService(
      store: store,
      identityService: _identityService,
    );
    _missionConverter = MissionConverterService(
      store: _store,
      repo: _todoRepository,
      identityService: _identityService,
    );
  }

  @override
  void dispose() {
    _syncOrchestrator.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TasksScreen(repo: _todoRepository, converter: _missionConverter),
      ApprovalsScreen(
        approvalService: _approvalService,
        ticketService: _ticketService,
        syncStatus: _syncStatus,
      ),
      PartnerScreen(
        repo: _todoRepository,
        loadSyncService: _loadSyncService,
        syncStatus: _syncStatus,
      ),
      SettingsScreen(
        identityService: _identityService,
        pairingService: _pairingService,
        syncStatus: _syncStatus,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: _PendingBadge(count: _approvalService.pendingTasks.length),
            label: 'Approvals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Partner',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
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
