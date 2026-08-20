import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kinetic_qr_scanner/kinetic_qr_scanner.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../l10n/generated/app_localizations.dart';
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
  bool _processing = false;

  void _onDetect(String raw) {
    if (_processing) return;
    _handlePayload(raw);
  }

  Future<void> _handlePayload(String raw) async {
    setState(() => _processing = true);

    try {
      final data = KineticEncryption.importKidsEnrollmentQrPayload(raw);
      if (!mounted) return;
      await _showConfirmDialog(data);
    } on FormatException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showError(l10n.invalidQrCode(e));
      if (mounted) setState(() => _processing = false);
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkFamilyTitle), centerTitle: false),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                KineticQrScanView(
                  enabled: !_processing,
                  onDetect: _onDetect,
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
                  l10n.scanQrCode,
                  style: tt.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.scanQrInstructions,
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
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.linkFamilyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.qrCodeFoundConfirm,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline,
            label: l10n.account,
            value: widget.data.username,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.cloud_outlined,
            label: l10n.server,
            value: widget.data.serverUrl,
          ),
          if (_needsPassword) ...[
            const SizedBox(height: 16),
            Text(
              l10n.enterWebDavPassword,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.webDavPassword,
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.link),
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
