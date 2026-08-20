import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../sync/webdav_config_repository.dart';

// ---------------------------------------------------------------------------
// KidsEnrollmentScreen
//
// Shown when the kids app has no stored WebDAV credentials.
// The child scans (or a parent scans on their behalf) a QR code produced by
// the parent app's "Kinderenapp koppelen" screen.
//
// Returns `true` via Navigator when enrollment succeeds.
// ---------------------------------------------------------------------------

class KidsEnrollmentScreen extends StatefulWidget {
  final WebDavConfigRepository configRepo;

  /// Called after successful enrollment. If provided, the widget calls this
  /// callback instead of popping the navigator.
  final VoidCallback? onEnrolled;

  const KidsEnrollmentScreen({
    super.key,
    required this.configRepo,
    this.onEnrolled,
  });

  @override
  State<KidsEnrollmentScreen> createState() => _KidsEnrollmentScreenState();
}

class _KidsEnrollmentScreenState extends State<KidsEnrollmentScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _scanner.dispose();
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
    await _scanner.stop();

    try {
      final data = KineticEncryption.importKidsEnrollmentQrPayload(raw);
      if (!mounted) return;
      await _showConfirmDialog(data);
    } on FormatException catch (e) {
      if (!mounted) return;
      _showError('Ongeldige QR-code: $e');
      if (mounted) {
        await _scanner.start();
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _showConfirmDialog(
    ({
      Uint8List familyKey,
      String serverUrl,
      String username,
      String password,
      String kidId,
    })
    data,
  ) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EnrollmentConfirmDialog(data: data),
    );

    if (password == null || !mounted) {
      await _scanner.start();
      setState(() => _processing = false);
      return;
    }

    await widget.configRepo.saveEnrollment(
      serverUrl: data.serverUrl,
      username: data.username,
      password: password,
      familyKey: data.familyKey,
      kidId: data.kidId,
    );

    if (mounted) {
      if (widget.onEnrolled != null) {
        widget.onEnrolled!();
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Familie koppelen'), centerTitle: false),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _scanner, onDetect: _onDetect),
                // Overlay with scan area indicator
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Container(
            color: scheme.surface,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan de QR-code',
                  style: tt.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Open de Kinetic-app van je ouder, ga naar '
                  'Instellingen → Familie → Kinderenapp koppelen, '
                  'scan de QR-code en typ daarna het WebDAV-wachtwoord.',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentConfirmDialog extends StatefulWidget {
  const _EnrollmentConfirmDialog({required this.data});

  final ({
    Uint8List familyKey,
    String serverUrl,
    String username,
    String password,
    String kidId,
  })
  data;

  @override
  State<_EnrollmentConfirmDialog> createState() =>
      _EnrollmentConfirmDialogState();
}

class _EnrollmentConfirmDialogState extends State<_EnrollmentConfirmDialog> {
  late final TextEditingController _passwordCtrl;
  bool _obscure = true;

  bool get _needsPassword => widget.data.password.isEmpty;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_needsPassword) {
      final typed = _passwordCtrl.text;
      if (typed.isEmpty) return;
      Navigator.of(context).pop(typed);
      return;
    }
    Navigator.of(context).pop(widget.data.password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Familie koppelen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR-code gevonden. Koppel dit apparaat aan de familie?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Account',
            value: widget.data.username,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.cloud_outlined,
            label: 'Server',
            value: widget.data.serverUrl,
          ),
          if (_needsPassword) ...[
            const SizedBox(height: 16),
            Text(
              'Typ het WebDAV-wachtwoord van je ouder. Dat staat niet in de QR-code.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'WebDAV-wachtwoord',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Koppelen'),
        ),
      ],
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
