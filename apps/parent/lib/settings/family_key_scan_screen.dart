import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';

// ---------------------------------------------------------------------------
// FamilyKeyScanScreen
//
// Uses the device camera to scan a QR code produced by FamilyKeyShareScreen
// on the partner's device. On a successful scan the payload is verified and
// the user is asked to confirm before the family key is saved.
// ---------------------------------------------------------------------------

class FamilyKeyScanScreen extends StatefulWidget {
  final SyncConfig currentConfig;
  final WebDavConfigRepository configRepo;

  const FamilyKeyScanScreen({
    super.key,
    required this.currentConfig,
    required this.configRepo,
  });

  @override
  State<FamilyKeyScanScreen> createState() => _FamilyKeyScanScreenState();
}

class _FamilyKeyScanScreenState extends State<FamilyKeyScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        _handlePayload(raw);
        return;
      }
    }
  }

  Future<void> _handlePayload(String raw) async {
    setState(() => _processing = true);
    await _controller.stop();

    try {
      final payload = KineticEncryption.importFamilyKeyQrPayload(raw);
      if (!mounted) return;
      await _showVerificationDialog(payload);
    } on FormatException catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Ongeldige QR-code: $e');
      // Resume scanning after error
      if (mounted) {
        await _controller.start();
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _showVerificationDialog(
    ({String username, String serverUrl, Uint8List familyKey}) payload,
  ) async {
    final currentUrl = _normalizeUrl(widget.currentConfig.serverUrl);
    final scannedUrl = _normalizeUrl(payload.serverUrl);
    final urlMatches = currentUrl == scannedUrl;
    final alreadyPaired = widget.currentConfig.familyKeyBytes != null;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              urlMatches ? Icons.check_circle_outline : Icons.warning_amber,
              color: urlMatches ? kColorTeal : Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Sleutel gevonden')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Partner',
              value: payload.username.isNotEmpty
                  ? payload.username
                  : '(onbekend)',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.cloud_outlined,
              label: 'Server',
              value: payload.serverUrl.isNotEmpty
                  ? payload.serverUrl
                  : '(onbekend)',
            ),
            if (!urlMatches) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'De server in de QR-code (${payload.serverUrl}) '
                        'komt niet overeen met jouw server (${widget.currentConfig.serverUrl}). '
                        'Weet je zeker dat je doorgaat?',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Is dit de juiste partner? Controleer de gebruikersnaam hierboven.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (alreadyPaired) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Je hebt al een familiesleutel. Als je een nieuwe importeert, '
                        'wordt data die al met de huidige sleutel is versleuteld '
                        'onleesbaar totdat je opnieuw synchroniseert.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Importeren'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await _importKey(payload.familyKey);
    } else {
      // User cancelled — resume scanning
      await _controller.start();
      setState(() => _processing = false);
    }
  }

  Future<void> _importKey(Uint8List familyKey) async {
    try {
      await widget.configRepo.saveFamilyKey(familyKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Familiesleutel opgeslagen.')),
      );
      Navigator.of(context).pop(true); // signal success to caller
    } on Exception catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Fout bij opslaan: $e');
      await _controller.start();
      setState(() => _processing = false);
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fout'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Normalises a URL for comparison: lowercase scheme + host, strip trailing slash.
  static String _normalizeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null)
      return url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final normalized = Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familiesleutel scannen'),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Scan overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: kColorTeal, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Richt op de QR-code van je partner',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Processing indicator
          if (_processing)
            Container(
              color: Colors.black.withAlpha(120),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Torch toggle
          Positioned(
            bottom: 40,
            right: 24,
            child: FloatingActionButton.small(
              backgroundColor: scheme.surfaceContainerHighest,
              onPressed: () => _controller.toggleTorch(),
              child: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (ctx, state, _) => Icon(
                  state.torchState == TorchState.on
                      ? Icons.flashlight_off
                      : Icons.flashlight_on,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
