import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../sync/sync_orchestrator.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';
import '../vault/family_vault_sync.dart';
import '../vault/screens/family_create_screen.dart';
import '../vault/screens/mnemonic_reveal_screen.dart';
import '../vault/widgets/mnemonic_phrase_field.dart';
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
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadPresence();
  }

  Future<void> _loadConfig() async {
    final config = await widget.configRepo.load();
    final paired = await widget.configRepo.isPartnerPaired();
    String? fingerprint;
    if (config?.familyKeyBytes != null) {
      fingerprint = await KineticVault.fingerprint(config!.familyKeyBytes!);
    }
    if (mounted)
      setState(() {
        _config = config;
        _partnerPaired = paired;
        _fingerprint = fingerprint;
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

  Future<bool> _ensureFamilyVault() async {
    final existing = await widget.configRepo.loadFamilyKey();
    if (existing != null) return true;
    if (!mounted) return false;
    final created = await Navigator.of(context).push<FamilyCreateResult>(
      MaterialPageRoute(builder: (_) => const FamilyCreateScreen()),
    );
    if (created == null) return false;
    await widget.configRepo.saveFamilyKey(
      created.key,
      entropy: created.entropy,
    );
    await FamilyVaultSync.pushIfPossible(widget.configRepo);
    await _loadConfig();
    return true;
  }

  Future<void> _exportFamilyKey() async {
    if (_config == null) return;
    if (!await _ensureFamilyVault()) return;
    if (!mounted) return;
    final config = await widget.configRepo.load();
    if (config == null || !mounted) return;
    final entropy = await widget.configRepo.loadFamilyEntropy();
    final keyWasGenerated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyKeyShareScreen(
          config: config,
          configRepo: widget.configRepo,
          entropy: entropy,
        ),
      ),
    );
    if ((keyWasGenerated ?? false) && mounted) {
      await widget.configRepo.setPartnerPaired(true);
      await FamilyVaultSync.pushIfPossible(widget.configRepo);
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
      await FamilyVaultSync.pushIfPossible(widget.configRepo);
      await _loadConfig();
      widget.onConfigSaved?.call();
    }
  }

  Future<void> _verifyFamilyPhrase() async {
    final stored = await widget.configRepo.loadFamilyKey();
    if (stored == null || !mounted) return;
    final ctrl = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Familiesleutel controleren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vul de 12 woorden in. We tonen ze niet; we controleren alleen of ze kloppen.',
            ),
            const SizedBox(height: 12),
            MnemonicPhraseField(controller: ctrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Controleren'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (phrase == null || !mounted) return;
    try {
      final derived = await KineticVault.deriveAesKey(phrase);
      final ok = KineticVault.equalKeys(stored, derived);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'De familiesleutel klopt.'
                : 'Deze herstelzin hoort niet bij deze familiesleutel.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deze herstelzin hoort niet bij deze familiesleutel.'),
        ),
      );
    }
  }

  Future<void> _revealFamilyPhrase() async {
    await showMnemonicReveal(
      context: context,
      title: 'Familiesleutel',
      loadWords: () async {
        final entropy = await widget.configRepo.loadFamilyEntropy();
        if (entropy == null) return null;
        return KineticVault.mnemonicFromEntropy(entropy);
      },
      missingMessage:
          'Deze familiesleutel is van voor de herstelzin (0.2) of kwam binnen '
          'als ruwe sleutel. We kunnen de woorden niet tonen. Maak een nieuwe '
          'familiesleutel en laat partner en kinderen opnieuw koppelen.',
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
            _PartnerStatusBanner(
              paired: paired,
              presenceList: partnerPresence,
              fingerprint: _fingerprint,
            ),
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
                  'Scan de QR of typ de 12 woorden van je partner.',
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
                  Icons.verified_user_outlined,
                  color: kColorTeal,
                ),
                title: const Text('Herstelzin controleren'),
                subtitle: const Text(
                  'Controleer of je de 12 woorden van de familiesleutel nog kent.',
                ),
                onTap: _verifyFamilyPhrase,
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: kColorTeal,
                ),
                title: const Text('Familiesleutel tonen'),
                subtitle: const Text(
                  'Toon de 12 woorden op dit apparaat (schermvergrendeling).',
                ),
                onTap: _revealFamilyPhrase,
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
  final String? fingerprint;

  const _PartnerStatusBanner({
    required this.paired,
    required this.presenceList,
    this.fingerprint,
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
                          ? 'Waarschuwing: partner voor het laatst gezien $lastSeenText'
                          : 'Partner voor het laatst gezien $lastSeenText',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ],
                  if (fingerprint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Vingerafdruk $fingerprint',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                        color: statusColor,
                      ),
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
