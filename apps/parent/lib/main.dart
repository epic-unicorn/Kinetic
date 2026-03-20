import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_sync/kinetic_sync.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'secure/flutter_secure_key_value_store.dart';

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
      home: const PairingScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Pairing Screen — Phase 1 entry point
// ---------------------------------------------------------------------------

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final IdentityService _identityService;
  late final PairingService _pairingService;
  late final SyncOrchestrator _syncOrchestrator;

  DeviceIdentity? _identity;
  String? _qrPayload;
  bool _isLoading = true;
  SyncStatus _syncStatus = SyncStatus.idle();

  @override
  void initState() {
    super.initState();
    _identityService = IdentityService(store: FlutterSecureKeyValueStore());
    _pairingService = PairingService(identityService: _identityService);
    // Orchestrator wired up without credentials for LAN CouchDB discovery.
    // Credentials are configured in Phase 5 (Docker / env vars).
    _syncOrchestrator = SyncOrchestrator(
      discoveryService: BonsoirMdnsDiscoveryService(),
      syncService: CouchSyncService(),
      meshKey: List<int>.filled(32, 0), // placeholder until FamilyPlan exists
    );
    _syncOrchestrator.statusStream.listen(
      (s) => setState(() => _syncStatus = s),
    );
    _syncOrchestrator.start();
    _load();
  }

  @override
  void dispose() {
    _syncOrchestrator.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final identity = await _identityService.getOrCreateIdentity();
    final qr = await _pairingService.generatePairingPayload(
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
              _SyncBanner(status: _syncStatus),
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
