import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../sync/sync_orchestrator.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';
import 'family_key_scan_screen.dart';
import 'family_key_share_screen.dart';

// ---------------------------------------------------------------------------
// PartnerSettingsScreen
//
// Manages partner pairing: share/scan family key QR, backup family key,
// and leaving the family.  Only reachable when WebDAV is configured.
// ---------------------------------------------------------------------------

class PartnerSettingsScreen extends StatefulWidget {
  final AppDatabase db;
  final WebDavConfigRepository configRepo;
  final SyncOrchestrator? syncOrchestrator;
  final VoidCallback? onConfigSaved;

  const PartnerSettingsScreen({
    super.key,
    required this.db,
    required this.configRepo,
    this.syncOrchestrator,
    this.onConfigSaved,
  });

  @override
  State<PartnerSettingsScreen> createState() => _PartnerSettingsScreenState();
}

class _PartnerSettingsScreenState extends State<PartnerSettingsScreen> {
  SyncConfig? _config;
  bool _partnerPaired = false;
  List<PresenceInfo> _presenceList = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadPresence();
  }

  Future<void> _loadConfig() async {
    final config = await widget.configRepo.load();
    final paired = await widget.configRepo.isPartnerPaired();
    if (mounted)
      setState(() {
        _config = config;
        _partnerPaired = paired;
      });
  }

  Future<void> _loadPresence() async {
    final orchestrator = widget.syncOrchestrator;
    if (orchestrator == null) return;
    try {
      final presence = await orchestrator.pullPresence();
      if (mounted) setState(() => _presenceList = presence);
    } catch (_) {}
  }

  Future<void> _exportFamilyKey() async {
    if (_config == null) return;
    final keyWasGenerated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyKeyShareScreen(
          config: _config!,
          configRepo: widget.configRepo,
        ),
      ),
    );
    if ((keyWasGenerated ?? false) && mounted) {
      await widget.configRepo.setPartnerPaired(true);
      await _loadConfig();
      widget.onConfigSaved?.call();
    }
  }

  Future<void> _importFamilyKey() async {
    if (_config == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyKeyScanScreen(
          currentConfig: _config!,
          configRepo: widget.configRepo,
        ),
      ),
    );
    if (result == true && mounted) {
      await widget.configRepo.setPartnerPaired(true);
      await _loadConfig();
      widget.onConfigSaved?.call();
    }
  }

  Future<void> _exportFamilyKeyBackup() async {
    final familyKey = _config?.familyKeyBytes;
    if (familyKey == null || !mounted) return;
    final json = KineticEncryption.exportFamilyKeyJson(
      familyKey,
      _config!.username,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Familiesleutel back-up'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bewaar dit JSON-bestand veilig. '
                'Iedereen met deze sleutel kan gedeelde data lezen.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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

  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partner ontkoppelen?'),
        content: const Text(
          'Alle gedeelde notities worden van dit apparaat verwijderd. '
          'Je eigen taken en privé-notities blijven behouden. '
          'Je partner verliest de verbinding niet — '
          'alleen jij verlaat de gedeelde werkruimte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verlaten'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await (widget.db.delete(
      widget.db.personalNotes,
    )..where((n) => n.isShared.equals(true))).go();
    await widget.db.delete(widget.db.partnerProposals).go();
    // Write disconnect tombstone so the other parent is notified.
    try {
      await widget.syncOrchestrator?.pushDisconnect();
    } catch (_) {}
    await widget.configRepo.clearFamilyKey();
    if (!mounted) return;
    widget.onConfigSaved?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final paired = _partnerPaired;

    // Partner presence: filter to other parents only.
    final partnerPresence = _presenceList
        .where((p) => p.deviceType == 'parent')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Partner'), centerTitle: false),
      body: ListView(
        children: [
          if (config != null) ...[
            const SizedBox(height: 8),
            _PartnerStatusBanner(paired: paired, presenceList: partnerPresence),
            const SizedBox(height: 8),
            if (!paired) ...[
              ListTile(
                leading: const Icon(Icons.people_outline, color: kColorTeal),
                title: const Text('Familiesleutel delen via QR'),
                subtitle: const Text(
                  'Laat je partner de QR-code scannen om samen te werken.',
                ),
                trailing: const Icon(Icons.qr_code),
                onTap: _exportFamilyKey,
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: kColorTeal),
                title: const Text('Familiesleutel scannen'),
                subtitle: const Text(
                  'Scan de QR-code op het apparaat van je partner.',
                ),
                onTap: _importFamilyKey,
              ),
            ],
            if (paired) ...[
              ListTile(
                leading: const Icon(Icons.qr_code, color: kColorTeal),
                title: const Text('Familiesleutel opnieuw delen'),
                subtitle: const Text(
                  'Deel de sleutel met een nieuw apparaat van je partner.',
                ),
                trailing: const Icon(Icons.qr_code),
                onTap: _exportFamilyKey,
              ),
              ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: kColorGold,
                ),
                title: const Text('Familiesleutel back-up exporteren'),
                subtitle: const Text(
                  'Sla de sleutel op als JSON-bestand voor noodgevallen.',
                ),
                onTap: _exportFamilyKeyBackup,
              ),
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Partner ontkoppelen',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text(
                  'Verwijder de familiesleutel en gedeelde notities van dit apparaat.',
                ),
                onTap: _leaveFamily,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PartnerStatusBanner extends StatelessWidget {
  final bool paired;
  final List<PresenceInfo> presenceList;

  const _PartnerStatusBanner({
    required this.paired,
    required this.presenceList,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Determine stale state: warn if partner hasn't synced in 14 days.
    final now = DateTime.now().toUtc();
    const staleThreshold = Duration(days: 14);
    final partnerPresence = presenceList.isNotEmpty ? presenceList.first : null;
    final isStale =
        partnerPresence != null &&
        now.difference(partnerPresence.lastSeen) > staleThreshold;
    final lastSeenText = partnerPresence != null
        ? _formatLastSeen(now, partnerPresence.lastSeen)
        : null;

    final statusColor = isStale
        ? scheme.error
        : paired
        ? kColorTeal
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isStale
              ? scheme.error.withAlpha(15)
              : paired
              ? kColorTeal.withAlpha(20)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isStale
                ? scheme.error.withAlpha(80)
                : paired
                ? kColorTeal.withAlpha(80)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isStale
                  ? Icons.warning_amber_rounded
                  : paired
                  ? Icons.people
                  : Icons.people_outline,
              size: 20,
              color: statusColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paired
                        ? 'Partner gekoppeld — familiesleutel aanwezig'
                        : 'Partner niet gekoppeld — scan of deel de QR-code om te koppelen',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                  if (lastSeenText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      isStale
                          ? 'Waarschuwing: partner voor het last gezien $lastSeenText'
                          : 'Partner voor het last gezien $lastSeenText',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatLastSeen(DateTime now, DateTime lastSeen) {
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 2) return 'zojuist';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minuten geleden';
    if (diff.inHours < 24) return '${diff.inHours} uur geleden';
    if (diff.inDays == 1) return 'gisteren';
    return '${diff.inDays} dagen geleden';
  }
}
