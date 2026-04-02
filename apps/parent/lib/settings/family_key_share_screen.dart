import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';

// ---------------------------------------------------------------------------
// FamilyKeyShareScreen
//
// Generates a family key in memory and displays it as a QR code.
// The key is NOT saved to storage until Parent A taps "Koppeling opslaan"
// after their partner has scanned the code.  If the user backs out without
// confirming, the ephemeral key is discarded.
//
// Returns `true` via Navigator when the key was saved so the caller can
// reload the config.
// ---------------------------------------------------------------------------

class FamilyKeyShareScreen extends StatefulWidget {
  final SyncConfig config;
  final WebDavConfigRepository configRepo;

  const FamilyKeyShareScreen({
    super.key,
    required this.config,
    required this.configRepo,
  });

  @override
  State<FamilyKeyShareScreen> createState() => _FamilyKeyShareScreenState();
}

class _FamilyKeyShareScreenState extends State<FamilyKeyShareScreen> {
  late SyncConfig _config;
  bool _saving = false;
  bool _keySaved = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    if (_config.familyKeyBytes == null) {
      // Generate in memory only — not persisted until user confirms.
      final newKey = KineticEncryption.generateFamilyKey();
      _config = _config.withFamilyKey(newKey);
    }
  }

  Future<void> _confirmAndSave() async {
    setState(() => _saving = true);
    await widget.configRepo.saveFamilyKey(_config.familyKeyBytes!);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _keySaved = true;
    });
  }

  String get _qrPayload => KineticEncryption.exportFamilyKeyQrPayload(
    _config.familyKeyBytes!,
    _config.serverUrl,
    _config.username,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Whether this key was freshly generated (vs already existed from storage)
    final isNewKey = widget.config.familyKeyBytes == null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Result is passed via the BackButton below; nothing to do here.
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Familiesleutel delen'),
          centerTitle: false,
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_keySaved),
          ),
          actions: [
            if (_config.familyKeyBytes != null)
              IconButton(
                icon: const Icon(Icons.text_snippet_outlined),
                tooltip: 'Exporteer als tekst',
                onPressed: () => _showTextExport(context),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Laat je partner deze QR-code scannen',
                  style: tt.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Open Instellingen → Familiesleutel scannen op het '
                  'apparaat van je partner en scan de code hieronder.',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // QR code
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
                    data: _qrPayload,
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

                const SizedBox(height: 32),

                // Server info badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_outlined, size: 18, color: kColorTeal),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _config.serverUrl,
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Confirm button — only shown for a newly generated key that
                // has not yet been saved.
                if (isNewKey && !_keySaved) ...[
                  FilledButton.icon(
                    onPressed: _saving ? null : _confirmAndSave,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving ? 'Opslaan…' : 'Partner heeft gescand — opslaan',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sla de sleutel op nadat je partner de QR-code heeft gescand.',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_keySaved)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: kColorTeal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Familiesleutel opgeslagen',
                        style: tt.bodySmall?.copyWith(color: kColorTeal),
                      ),
                    ],
                  )
                else
                  Text(
                    'Sta niemand anders toe de code te scannen. '
                    'Iedereen met deze sleutel kan gedeelde data lezen.',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTextExport(BuildContext context) {
    final familyKey = _config.familyKeyBytes;
    if (familyKey == null) return;
    final json = KineticEncryption.exportFamilyKeyJson(
      familyKey,
      _config.username,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Familiesleutel (tekst)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gebruik dit alleen als noodoplossing. '
                'Bewaar de sleutel veilig — '
                'iedereen die hem heeft kan gedeelde data lezen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }
}
