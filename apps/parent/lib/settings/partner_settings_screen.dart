import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../l10n/generated/app_localizations.dart';
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
    if (mounted) {
      setState(() {
        _config = config;
        _partnerPaired = paired;
        _fingerprint = fingerprint;
      });
    }
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
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.partnerVerifyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.partnerVerifyBody),
            const SizedBox(height: 12),
            MnemonicPhraseField(controller: ctrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l10n.commonVerify),
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
            ok ? l10n.partnerVerifyOk : l10n.partnerVerifyMismatch,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.partnerVerifyMismatch)),
      );
    }
  }

  Future<void> _revealFamilyPhrase() async {
    final l10n = AppLocalizations.of(context);
    await showMnemonicReveal(
      context: context,
      title: l10n.familyCreateTitle,
      loadWords: () async {
        final entropy = await widget.configRepo.loadFamilyEntropy();
        if (entropy == null) return null;
        return KineticVault.mnemonicFromEntropy(entropy);
      },
      missingMessage: l10n.partnerRevealMissing,
    );
  }

  Future<void> _leaveFamily() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.partnerUnlinkTitle),
        content: Text(l10n.partnerUnlinkBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonLeave),
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
    final l10n = AppLocalizations.of(context);
    final config = _config;
    final paired = _partnerPaired;

    // Partner presence: filter to other parents only.
    final partnerPresence = _presenceList
        .where((p) => p.deviceType == 'parent')
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPartner), centerTitle: false),
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
                title: Text(l10n.partnerShareViaQr),
                subtitle: Text(l10n.partnerShareViaQrSubtitle),
                trailing: const Icon(Icons.qr_code),
                onTap: _exportFamilyKey,
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: kColorTeal),
                title: Text(l10n.partnerScanKey),
                subtitle: Text(l10n.partnerScanKeySubtitle),
                onTap: _importFamilyKey,
              ),
            ],
            if (paired) ...[
              ListTile(
                leading: const Icon(Icons.qr_code, color: kColorTeal),
                title: Text(l10n.partnerReshareKey),
                subtitle: Text(l10n.partnerReshareKeySubtitle),
                trailing: const Icon(Icons.qr_code),
                onTap: _exportFamilyKey,
              ),
              ListTile(
                leading: const Icon(
                  Icons.verified_user_outlined,
                  color: kColorTeal,
                ),
                title: Text(l10n.partnerVerifyPhrase),
                subtitle: Text(l10n.partnerVerifyPhraseSubtitle),
                onTap: _verifyFamilyPhrase,
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: kColorTeal,
                ),
                title: Text(l10n.partnerShowKey),
                subtitle: Text(l10n.partnerShowKeySubtitle),
                onTap: _revealFamilyPhrase,
              ),
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.partnerUnlink,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(l10n.partnerUnlinkSubtitle),
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Determine stale state: warn if partner hasn't synced in 14 days.
    final now = DateTime.now().toUtc();
    const staleThreshold = Duration(days: 14);
    final partnerPresence = presenceList.isNotEmpty ? presenceList.first : null;
    final isStale =
        partnerPresence != null &&
        now.difference(partnerPresence.lastSeen) > staleThreshold;
    final lastSeenText = partnerPresence != null
        ? _formatLastSeen(l10n, now, partnerPresence.lastSeen)
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
                        ? l10n.partnerStatusPaired
                        : l10n.partnerStatusUnpaired,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                  if (lastSeenText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      isStale
                          ? l10n.partnerLastSeenWarning(lastSeenText)
                          : l10n.partnerLastSeen(lastSeenText),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ],
                  if (fingerprint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.partnerFingerprint(fingerprint!),
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

  static String _formatLastSeen(
    AppLocalizations l10n,
    DateTime now,
    DateTime lastSeen,
  ) {
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 2) return l10n.relativeJustNow;
    if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.relativeYesterday;
    return l10n.relativeDaysAgo(diff.inDays);
  }
}
