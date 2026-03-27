import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../secure/flutter_secure_key_value_store.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Key names used in FlutterSecureKeyValueStore for runtime credentials.
// ---------------------------------------------------------------------------
const kMeshKeyHexKey = 'kinetic_mesh_key_hex';
const kCouchUserKey = 'kinetic_couch_user';
const kCouchPasswordKey = 'kinetic_couch_password';

/// First-launch screen shown when no mesh key is found in secure storage.
///
/// The parent scans the QR displayed on the hub's `/enroll` page, which
/// contains `{mk, cu, cp}` embedded in the standard [PairingData] payload.
///
/// Alternatively the user can choose "Use standalone" to skip hub setup
/// entirely — family sync is disabled until they enroll later from Settings.
///
/// On success [onEnrolled] is called so the caller can rebuild with sync
/// enabled.  On skip [onSkip] is called.
class HubEnrollmentScreen extends StatefulWidget {
  final PairingService pairingService;
  final void Function(List<int> meshKey, String couchUser, String couchPassword)
  onEnrolled;
  final VoidCallback onSkip;

  const HubEnrollmentScreen({
    super.key,
    required this.pairingService,
    required this.onEnrolled,
    required this.onSkip,
  });

  @override
  State<HubEnrollmentScreen> createState() => _HubEnrollmentScreenState();
}

class _HubEnrollmentScreenState extends State<HubEnrollmentScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final data = widget.pairingService.parsePairingPayload(raw);

      final meshKeyBytes = base64Decode(data.meshKeyBase64);
      final meshKeyHex = meshKeyBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      final couchUser = data.couchUsername ?? 'kinetic';
      final couchPassword = data.couchPassword ?? 'changeme';

      final store = FlutterSecureKeyValueStore();
      await store.write(key: kMeshKeyHexKey, value: meshKeyHex);
      await store.write(key: kCouchUserKey, value: couchUser);
      await store.write(key: kCouchPasswordKey, value: couchPassword);

      widget.onEnrolled(meshKeyBytes, couchUser, couchPassword);
    } on FormatException catch (e) {
      setState(() {
        _processing = false;
        _error = 'Ongeldige QR-code: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _error = 'Fout: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCharcoal,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Verbinden met hub',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: kColorTeal,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Scan de QR-code op het hub-scherm\n(http://<hub-ip>:8765/enroll)',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: kColorWarmGrey),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      MobileScanner(controller: _scanner, onDetect: _onDetect),
                      if (_processing)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      // Viewfinder overlay
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: kColorTeal, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kColorWarmGrey,
                        side: const BorderSide(color: kColorWarmGrey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: widget.onSkip,
                      child: const Text('Overslaan — zonder hub gebruiken'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Je kunt later verbinden via Instellingen.',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: kColorWarmGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
