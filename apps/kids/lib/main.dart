import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_support/kinetic_support.dart';
import 'package:kinetic_sync/kinetic_sync.dart';

import 'secure/flutter_secure_key_value_store.dart';

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
      'de10de10de10de10de10de10de10de10de10de10de10de10de10de10de10de10',
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
          seedColor: const Color(0xFFE7BB41),
          brightness: Brightness.dark,
        ),
      ),
      home: const _KidsShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Shell — owns all shared services.
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

  DeviceIdentity? _identity;

  @override
  void initState() {
    super.initState();
    _identityService = IdentityService(store: FlutterSecureKeyValueStore());
    _syncService = CouchSyncService();
    _syncOrchestrator = SyncOrchestrator(
      discoveryService: BonsoirMdnsDiscoveryService(),
      syncService: _syncService,
      meshKey: _parseMeshKey(),
      credentials: (username: _kCouchUser, password: _kCouchPassword),
    );
    _syncOrchestrator.start();

    final store = _SyncDocumentStore(_syncService);
    _approvalService = ApprovalService(store: store);

    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final id = await _identityService.getOrCreateIdentity();
    if (mounted) setState(() => _identity = id);
  }

  @override
  void dispose() {
    _syncOrchestrator.dispose();
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
  final CouchSyncService syncService;

  const KidsHomeScreen({
    super.key,
    required this.identity,
    required this.approvalService,
    required this.syncService,
  });

  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen> {
  void _refresh() => setState(() {});

  /// Detect tasks whose dueDate + 1 day has passed and mark them overdue.
  /// Returns true if any task was updated (triggers rebuild).
  bool _checkOverdueTasks() {
    final now = DateTime.now().toUtc();
    bool changed = false;
    for (final doc in widget.syncService.localDocs) {
      if (doc['assignedToId'] != widget.identity.deviceId) continue;
      final statusStr = doc['status'] as String? ?? '';
      if (statusStr == TaskStatus.completed.name ||
          statusStr == TaskStatus.pendingApproval.name ||
          statusStr == TaskStatus.overdue.name)
        continue;
      final dueDateStr = doc['dueDate'] as String?;
      if (dueDateStr == null) continue;
      final dueDate = DateTime.parse(dueDateStr);
      if (now.isAfter(dueDate.add(const Duration(days: 1)))) {
        widget.syncService.upsertLocal({
          ...doc,
          'status': TaskStatus.overdue.name,
          'updatedAt': now.toIso8601String(),
        });
        changed = true;
      }
    }
    return changed;
  }

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
    // Check and auto-mark overdue tasks after the frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checkOverdueTasks()) setState(() {});
    });

    final ledgerDoc = widget.syncService.localDocs
        .where((d) => d['_id'] == 'xp:${widget.identity.deviceId}')
        .firstOrNull;
    final xpBalance = ledgerDoc == null
        ? 0
        : XpLedger.fromJson(ledgerDoc).balance;
    final tasks = _myTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn Opdrachten'), centerTitle: true),
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
    );
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
          const Icon(Icons.star, color: Color(0xFFE7BB41), size: 28),
          const SizedBox(width: 8),
          Text(
            '$balance XP',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE7BB41),
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
          Icon(Icons.celebration, size: 64, color: Color(0xFFE7BB41)),
          SizedBox(height: 16),
          Text(
            'Alles klaar! Geen opdrachten op dit moment.',
            style: TextStyle(color: Color(0xFFD3D0CB)),
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
        subtitle: _buildSubtitle(),
        trailing: _actionButton(),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (task.xpReward > 0) parts.add('+${task.xpReward} XP');
    if (task.dueDate != null) {
      final d = task.dueDate!.toLocal();
      parts.add('Inleveren vóór ${d.day}-${d.month}-${d.year}');
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  ·  '),
      style: TextStyle(
        color: task.status == TaskStatus.overdue
            ? Colors.redAccent
            : Colors.amber,
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
      TaskStatus.overdue => const Icon(Icons.schedule, color: Colors.redAccent),
    };
  }

  Widget? _actionButton() {
    if (task.status == TaskStatus.pendingApproval) {
      return const Chip(label: Text('Wachten…'));
    }
    if (task.status == TaskStatus.overdue) {
      return Chip(
        label: const Text('Niet op tijd'),
        backgroundColor: Colors.redAccent.withAlpha(40),
        labelStyle: const TextStyle(color: Colors.redAccent),
      );
    }
    if (task.status == TaskStatus.pending ||
        task.status == TaskStatus.inProgress) {
      final isHabit = task.category == TaskCategory.habit;
      return FilledButton.tonal(
        onPressed: _handleSubmit,
        child: Text(isHabit ? 'Klaar' : 'Inleveren'),
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
