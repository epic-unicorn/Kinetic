import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_sync/kinetic_sync.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// SettingsScreen — device pairing + app settings.
// (Pairing is moved here from the old primary tab so the Tasks tab is
//  the natural landing screen for daily use.)
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  final IdentityService identityService;
  final PairingService pairingService;
  final SyncStatus syncStatus;

  const SettingsScreen({
    super.key,
    required this.identityService,
    required this.pairingService,
    required this.syncStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        children: [
          // ── Pairing section ──────────────────────────────────────────────
          const _SectionHeader(label: 'Device pairing'),
          ListTile(
            leading: const Icon(Icons.qr_code, color: kColorTeal),
            title: const Text('Pair a device'),
            subtitle: const Text('Show QR code to add another phone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PairingPage(
                  identityService: identityService,
                  pairingService: pairingService,
                  syncStatus: syncStatus,
                ),
              ),
            ),
          ),

          // ── Sync status ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Sync'),
          ListTile(
            leading: _syncIcon(syncStatus),
            title: Text(_syncLabel(syncStatus)),
            subtitle: const Text('Home server (hub)'),
          ),

          // ── About ────────────────────────────────────────────────────────
          const _SectionHeader(label: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: kColorWarmGrey),
            title: const Text('Kinetic Link'),
            subtitle: const Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _syncIcon(SyncStatus s) => switch (s.state) {
    SyncState.syncing => const Icon(Icons.sync, color: Colors.blueAccent),
    SyncState.error => const Icon(Icons.error_outline, color: Colors.redAccent),
    SyncState.idle when s.lastResult != null => const Icon(
      Icons.cloud_done_outlined,
      color: Colors.greenAccent,
    ),
    _ => const Icon(Icons.cloud_off, color: kColorWarmGrey),
  };

  String _syncLabel(SyncStatus s) => switch (s.state) {
    SyncState.syncing => 'Syncing…',
    SyncState.error => s.errorMessage ?? 'Sync error',
    SyncState.idle when s.lastResult != null =>
      'Synced ↑${s.lastResult!.pushed} ↓${s.lastResult!.pulled}',
    _ => 'Waiting for home server',
  };
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: kColorWarmGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dedicated pairing page (pushed from settings)
// ---------------------------------------------------------------------------

class _PairingPage extends StatefulWidget {
  final IdentityService identityService;
  final PairingService pairingService;
  final SyncStatus syncStatus;

  const _PairingPage({
    required this.identityService,
    required this.pairingService,
    required this.syncStatus,
  });

  @override
  State<_PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<_PairingPage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pair Device'), centerTitle: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
                      ).textTheme.bodyMedium?.copyWith(color: kColorWarmGrey),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kColorOffWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: _qrPayload!,
                        size: 220,
                        backgroundColor: kColorOffWhite,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DeviceBadge(
                      shortId: _identity!.deviceId
                          .substring(0, 8)
                          .toUpperCase(),
                    ),
                    const Spacer(),
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
            'Device $shortId\u2026',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
