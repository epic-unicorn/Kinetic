import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';

/// Shows a family-pairing QR that carries 16-byte BIP-39 entropy (no password).
class FamilyKeyShareScreen extends StatefulWidget {
  const FamilyKeyShareScreen({
    super.key,
    required this.config,
    required this.configRepo,
    this.entropy,
  });

  final SyncConfig config;
  final WebDavConfigRepository configRepo;
  final Uint8List? entropy;

  @override
  State<FamilyKeyShareScreen> createState() => _FamilyKeyShareScreenState();
}

class _FamilyKeyShareScreenState extends State<FamilyKeyShareScreen> {
  Uint8List? _entropy;
  String? _fingerprint;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _entropy = widget.entropy;
    _load();
  }

  Future<void> _load() async {
    final entropy = _entropy ?? await widget.configRepo.loadFamilyEntropy();
    final key = widget.config.familyKeyBytes;
    String? fingerprint;
    if (key != null) {
      fingerprint = await KineticVault.fingerprint(key);
    }
    if (!mounted) return;
    setState(() {
      _entropy = entropy;
      _fingerprint = fingerprint;
    });
  }

  String? get _qrPayload {
    final entropy = _entropy;
    if (entropy != null) {
      return KineticVault.exportFamilyEntropyQrPayload(
        entropy: entropy,
        serverUrl: widget.config.serverUrl,
        username: widget.config.username,
      );
    }
    final key = widget.config.familyKeyBytes;
    if (key == null) return null;
    return KineticEncryption.exportFamilyKeyQrPayload(
      key,
      widget.config.serverUrl,
      widget.config.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final qr = _qrPayload;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familiesleutel delen'),
        centerTitle: false,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_confirmed),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                _entropy == null
                    ? 'Laat je partner deze QR-code scannen. Deze familiesleutel '
                        'is van vóór de herstelzin en heeft geen 12 woorden.'
                    : 'Laat je partner deze QR-code scannen, of de 12 woorden typen.',
                style: tt.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'De code bevat geen WebDAV-wachtwoord. Controleer samen de vingerafdruk.',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (qr == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Geen herstelzin-gegevens op dit apparaat. '
                    'Maak een nieuwe familiesleutel.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Container(
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
                    data: qr,
                    version: QrVersions.auto,
                    size: 260,
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
              const SizedBox(height: 20),
              if (_fingerprint != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Vingerafdruk  $_fingerprint',
                    style: tt.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              const Spacer(),
              if (!_confirmed)
                FilledButton.icon(
                  onPressed: () => setState(() => _confirmed = true),
                  icon: const Icon(Icons.check),
                  label: const Text('Partner heeft gescand'),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: kColorTeal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Familiesleutel gedeeld',
                      style: tt.bodySmall?.copyWith(color: kColorTeal),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
