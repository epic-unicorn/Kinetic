import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import 'db/app_database.dart';
import 'enrollment/hub_enrollment_screen.dart';
import 'partner/screens/partner_screen.dart';
import 'partner/services/load_sync_service.dart';
import 'secure/flutter_secure_key_value_store.dart';
import 'settings/settings_screen.dart';
import 'support/couch_document_store.dart';
import 'support/parent_notification_service.dart';
import 'todo/screens/tasks_screen.dart';
import 'todo/services/mission_converter_service.dart';
import 'todo/services/todo_repository.dart';

// ---------------------------------------------------------------------------
// Dev-only fallback credentials used when no key is stored and the app runs
// in debug mode (matches hub/.env.example defaults).
// ---------------------------------------------------------------------------
const _kDevMeshKeyHex =
    'de10de10de10de10de10de10de10de10de10de10de10de10de10de10de10de10';
const _kDevCouchUser = 'kinetic';
const _kDevCouchPassword = 'changeme';

List<int> _hexToBytes(String hex) => List.generate(
  32,
  (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
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
  SyncOrchestrator? _syncOrchestrator;
  late final ApprovalService _approvalService;
  late final TicketService _ticketService;
  late final AppDatabase _db;
  late final ParentNotificationService _notifSvc;
  late final TodoRepository _todoRepository;
  late final LoadSyncService _loadSyncService;
  late final CouchDocumentStore _store;
  late final MissionConverterService _missionConverter;

  // null = still checking storage; false = need enrollment; true = ready
  bool? _enrolled;
  int _selectedIndex = 0;
  SyncStatus _syncStatus = SyncStatus.idle();

  @override
  void initState() {
    super.initState();
    _identityService = IdentityService(store: FlutterSecureKeyValueStore());
    _pairingService = PairingService(identityService: _identityService);
    _syncService = CouchSyncService();

    final store = CouchDocumentStore(_syncService);
    _store = store;
    _approvalService = ApprovalService(store: store);
    _ticketService = TicketService(store: store);

    _db = AppDatabase();
    _notifSvc = ParentNotificationService();
    _todoRepository = TodoRepository(db: _db, notifications: _notifSvc);
    _loadSyncService = LoadSyncService(
      store: store,
      identityService: _identityService,
    );
    _missionConverter = MissionConverterService(
      store: _store,
      repo: _todoRepository,
      identityService: _identityService,
      notifications: _notifSvc,
    );

    _checkEnrollment();
  }

  Future<void> _checkEnrollment() async {
    // In debug mode use the dev fallback so `flutter run` still works.
    if (kDebugMode) {
      _startSync(
        _hexToBytes(_kDevMeshKeyHex),
        _kDevCouchUser,
        _kDevCouchPassword,
      );
      if (mounted) setState(() => _enrolled = true);
      return;
    }

    final secStore = FlutterSecureKeyValueStore();
    final hex = await secStore.read(key: kMeshKeyHexKey);
    if (hex == null) {
      if (mounted) setState(() => _enrolled = false);
      return;
    }

    final user = await secStore.read(key: kCouchUserKey) ?? _kDevCouchUser;
    final pass =
        await secStore.read(key: kCouchPasswordKey) ?? _kDevCouchPassword;
    _startSync(_hexToBytes(hex), user, pass);
    if (mounted) setState(() => _enrolled = true);
  }

  void _startSync(List<int> meshKey, String couchUser, String couchPassword) {
    _syncOrchestrator?.dispose();
    _syncOrchestrator = SyncOrchestrator(
      discoveryService: BonsoirMdnsDiscoveryService(),
      syncService: _syncService,
      meshKey: meshKey,
      credentials: (username: couchUser, password: couchPassword),
    );
    _syncOrchestrator!.statusStream.listen(
      (s) => setState(() => _syncStatus = s),
    );
    _syncOrchestrator!.start();
  }

  void _onEnrolled(List<int> meshKey, String couchUser, String couchPassword) {
    _startSync(meshKey, couchUser, couchPassword);
    setState(() => _enrolled = true);
  }

  void _onSkip() => setState(() => _enrolled = true); // standalone, no sync

  @override
  void dispose() {
    _syncOrchestrator?.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Still checking secure storage.
    if (_enrolled == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // First launch — no mesh key stored yet.
    if (_enrolled == false) {
      return HubEnrollmentScreen(
        pairingService: _pairingService,
        onEnrolled: _onEnrolled,
        onSkip: _onSkip,
      );
    }

    final screens = [
      TasksScreen(
        repo: _todoRepository,
        converter: _missionConverter,
        syncService: _loadSyncService,
      ),
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
        onReenroll: _onEnrolled,
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
            label: 'Taken',
          ),
          NavigationDestination(
            icon: _PendingBadge(count: _approvalService.pendingTasks.length),
            label: 'Goedkeuren',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Partner',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Instellingen',
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
        'Gesynchroniseerd ↑${status.lastResult!.pushed} ↓${status.lastResult!.pulled}',
        Colors.greenAccent,
      ),
      SyncState.syncing => (
        Icons.sync,
        'Synchroniseren met ${status.peer?.deviceId.substring(0, 8) ?? '…'}',
        Colors.blueAccent,
      ),
      SyncState.error => (
        Icons.error_outline,
        status.errorMessage ?? 'Synchronisatiefout',
        Colors.redAccent,
      ),
      _ => (Icons.cloud_off, 'Wachten op thuisserver…', Colors.white38),
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
        title: const Text('Goedkeuren & Hulp'),
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
                    label: 'Bewijs ingediend (${pendingTasks.length})',
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
                  _SectionHeader(
                    label: 'Hulpverzoeken (${openTickets.length})',
                  ),
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
            'Alles in orde — niets te beoordelen.',
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
              tooltip: 'Goedkeuren',
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
              tooltip: 'Afwijzen',
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
          ticket.description ?? 'Geen beschrijving',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: TextButton(
          child: const Text('Oplossen'),
          onPressed: () {
            ticketService.updateStatus(
              ticket.id,
              status: TicketStatus.resolved,
              resolvedById: 'parent',
              resolution: 'Opgelost door ouder',
            );
            onDone();
          },
        ),
      ),
    );
  }
}
