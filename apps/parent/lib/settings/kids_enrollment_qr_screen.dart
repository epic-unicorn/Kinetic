import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';

// ---------------------------------------------------------------------------
// KidsEnrollmentQrScreen
//
// Two-step screen:
//   1. User enters the child's name.
//   2. QR code is shown; child scans it to enroll.
// The child is registered in [configRepo] so the family screen can list and
// manage enrolled children.
// ---------------------------------------------------------------------------

class KidsEnrollmentQrScreen extends StatefulWidget {
  final SyncConfig config;
  final WebDavConfigRepository? configRepo;
  final VoidCallback? onKidRegistered;

  const KidsEnrollmentQrScreen({
    super.key,
    required this.config,
    this.configRepo,
    this.onKidRegistered,
  });

  @override
  State<KidsEnrollmentQrScreen> createState() => _KidsEnrollmentQrScreenState();
}

class _KidsEnrollmentQrScreenState extends State<KidsEnrollmentQrScreen> {
  final _nameCtrl = TextEditingController();
  String? _registeredName;
  String? _registeredKidId;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _qrPayload => KineticEncryption.exportKidsEnrollmentQrPayload(
    widget.config.familyKeyBytes!,
    widget.config.serverUrl,
    widget.config.username,
    kidId: _registeredKidId!,
  );

  Future<void> _registerAndShowQr() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    String kidId = '';
    if (widget.configRepo != null) {
      final kid = await widget.configRepo!.addEnrolledKid(name);
      kidId = kid.id;
      widget.onKidRegistered?.call();
    }
    if (mounted) {
      setState(() {
        _registeredName = name;
        _registeredKidId = kidId;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kidsEnrollTitle),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _registeredName == null
              ? _buildNameStep(context, scheme, tt, l10n)
              : _buildQrStep(context, scheme, tt, l10n),
        ),
      ),
    );
  }

  Widget _buildNameStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme tt,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.kidsEnrollNameTitle,
          style: tt.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.kidsEnrollNameBody,
          style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.kidsEnrollNameLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.child_care),
          ),
          onSubmitted: (_) => _registerAndShowQr(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _registerAndShowQr,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.kidsEnrollContinueToQr),
        ),
      ],
    );
  }

  Widget _buildQrStep(
    BuildContext context,
    ColorScheme scheme,
    TextTheme tt,
    AppLocalizations l10n,
  ) {
    final name = _registeredName!;
    return Column(
      children: [
        Text(
          l10n.kidsEnrollQrTitle(name),
          style: tt.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.kidsEnrollQrBody(name),
          style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrPayload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kColorTeal.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kColorTeal.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: kColorTeal),
                  const SizedBox(width: 8),
                  Text(
                    l10n.kidsEnrollWhatShared,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kColorTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.kidsEnrollWhatSharedBody,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
