import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../secure/flutter_secure_key_value_store.dart';

// ---------------------------------------------------------------------------
// Key names shared with the parent app (must stay in sync).
// ---------------------------------------------------------------------------
const kMeshKeyHexKey = 'kinetic_mesh_key_hex';
const kCouchUserKey = 'kinetic_couch_user';
const kCouchPasswordKey = 'kinetic_couch_password';

/// First-launch screen for the kids app.
///
/// The parent opens Settings → "Voeg kindertoestel toe" which displays a QR
/// that contains the shared mesh key + CouchDB credentials.  This screen
/// scans that QR and persists the credentials in secure storage.
///
/// [onEnrolled] is called with the decoded bytes so the caller can start sync.
class ChildEnrollmentScreen extends StatefulWidget {
  final PairingService pairingService;
  final void Function(List<int> meshKey, String couchUser, String couchPassword)
  onEnrolled;

  const ChildEnrollmentScreen({
    super.key,
    required this.pairingService,
    required this.onEnrolled,
  });

  @override
  State<ChildEnrollmentScreen> createState() => _ChildEnrollmentScreenState();
}

class _ChildEnrollmentScreenState extends State<ChildEnrollmentScreen> {
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
    const gold = Color(0xFFE7BB41);
    const charcoal = Color(0xFF393E41);
    const warmGrey = Color(0xFFD3D0CB);

    return Scaffold(
      backgroundColor: charcoal,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.qr_code_scanner, size: 56, color: gold),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Koppelen met ouder',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Scan de QR-code die de ouder-app toont\nonder Instellingen → Kindertoestel toevoegen.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: warmGrey),
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
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: gold, width: 2),
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
