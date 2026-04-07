import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_themes.dart';

// ---------------------------------------------------------------------------
// KidsEnrollmentQrScreen
//
// Shows a QR code that the kids app can scan to enroll in the family.
// The payload includes server URL, username, password, and the family key.
// Only reachable when a family key is present.
// ---------------------------------------------------------------------------

class KidsEnrollmentQrScreen extends StatelessWidget {
  final SyncConfig config;

  const KidsEnrollmentQrScreen({super.key, required this.config});

  String get _qrPayload => KineticEncryption.exportKidsEnrollmentQrPayload(
        config.familyKeyBytes!,
        config.serverUrl,
        config.username,
        config.password,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinderenapp koppelen'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Scan met de Kinetic-kinderenapp',
                style: tt.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open de kinderenapp en volg de stappen om te koppelen. '
                'Houd je scherm bij de hand.',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // QR code
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
              // Info card
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
                        const Icon(Icons.info_outline,
                            size: 18, color: kColorTeal),
                        const SizedBox(width: 8),
                        Text(
                          'Wat wordt er gedeeld?',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kColorTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deze QR-code bevat je WebDAV-inloggegevens en '
                      'de familiesleutel. Deel hem alleen met de kinderenapp '
                      'op een vertrouwd apparaat.',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
