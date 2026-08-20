import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../l10n/generated/app_localizations.dart';
import '../sync/sync_orchestrator.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';
import '../vault/family_vault_sync.dart';
import '../vault/screens/family_create_screen.dart';
import 'kids_enrollment_qr_screen.dart';
import 'models/enrolled_kid.dart';

// ---------------------------------------------------------------------------
// KidsSettingsScreen
//
// Manages kids enrollment: shows a QR for the kids app to scan, lists
// enrolled kids and allows removing them.
//
// Available as soon as WebDAV is configured — no partner pairing required.
// Without a family vault the parent first writes down 12 words.
// ---------------------------------------------------------------------------

class KidsSettingsScreen extends StatefulWidget {
  final WebDavConfigRepository configRepo;
  final SyncOrchestrator? syncOrchestrator;
  final VoidCallback? onConfigSaved;

  const KidsSettingsScreen({
    super.key,
    required this.configRepo,
    this.syncOrchestrator,
    this.onConfigSaved,
  });

  @override
  State<KidsSettingsScreen> createState() => _KidsSettingsScreenState();
}

class _KidsSettingsScreenState extends State<KidsSettingsScreen> {
  List<EnrolledKid> _enrolledKids = [];
  Map<String, PresenceInfo> _presenceByKidId = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPresence();
  }

  Future<void> _loadData() async {
    final kids = await widget.configRepo.loadEnrolledKids();
    if (mounted) {
      setState(() {
        _enrolledKids = kids;
      });
    }
  }

  Future<void> _loadPresence() async {
    final orchestrator = widget.syncOrchestrator;
    if (orchestrator == null) return;
    try {
      final presence = await orchestrator.pullPresence();
      final kidPresence = <String, PresenceInfo>{};
      for (final p in presence) {
        if (p.deviceType == 'kid') kidPresence[p.deviceId] = p;
      }
      if (mounted) setState(() => _presenceByKidId = kidPresence);
    } catch (_) {}
  }

  Future<void> _enrollKid() async {
    var familyKey = await widget.configRepo.loadFamilyKey();
    if (familyKey == null) {
      if (!mounted) return;
      final created = await Navigator.of(context).push<FamilyCreateResult>(
        MaterialPageRoute(builder: (_) => const FamilyCreateScreen()),
      );
      if (created == null) return;
      await widget.configRepo.saveFamilyKey(
        created.key,
        entropy: created.entropy,
      );
      await FamilyVaultSync.pushIfPossible(widget.configRepo);
      familyKey = created.key;
    }
    final config = await widget.configRepo.load();
    if (!mounted || config == null || config.familyKeyBytes == null) return;
    widget.onConfigSaved?.call();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KidsEnrollmentQrScreen(
          config: config,
          configRepo: widget.configRepo,
          onKidRegistered: _loadData,
        ),
      ),
    );
    await _loadData();
    if (mounted) widget.onConfigSaved?.call();
  }

  Future<void> _confirmRemoveKid(EnrolledKid kid) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.kidsRemoveTitle(kid.name)),
        content: Text(l10n.kidsRemoveBody(kid.name)),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Write disconnect tombstone so the kid's device knows it was removed.
    try {
      await widget.syncOrchestrator?.pushKidDisconnect(kid);
    } catch (_) {}
    await widget.configRepo.removeEnrolledKid(kid.id);
    await _loadData();
    if (mounted) widget.onConfigSaved?.call();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}-${local.month}-${local.year}';
  }

  Widget _buildKidSubtitle(BuildContext context, EnrolledKid kid) {
    final l10n = AppLocalizations.of(context);
    final presence = _presenceByKidId[kid.id];
    final enrolledText = l10n.kidsEnrolledOn(_formatDate(kid.enrolledAt));
    if (presence == null) {
      return Text(enrolledText);
    }
    final now = DateTime.now().toUtc();
    final diff = now.difference(presence.lastSeen);
    final stale = diff.inDays >= 14;
    final lastSeenText = _formatLastSeen(l10n, diff);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(enrolledText),
        Text(
          stale
              ? l10n.kidsLastSeenWarning(lastSeenText)
              : l10n.kidsLastSeen(lastSeenText),
          style: TextStyle(
            fontSize: 11,
            color: stale
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _formatLastSeen(AppLocalizations l10n, Duration diff) {
    if (diff.inMinutes < 2) return l10n.relativeJustNow;
    if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.relativeYesterday;
    return l10n.relativeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsKids), centerTitle: false),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.child_care, color: kColorTeal),
            title: Text(l10n.kidsLinkApp),
            subtitle: Text(l10n.kidsLinkAppSubtitle),
            trailing: const Icon(Icons.qr_code),
            onTap: _enrollKid,
          ),
          if (_enrolledKids.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.kidsEnrolledSection,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            for (final kid in _enrolledKids)
              ListTile(
                leading: const Icon(Icons.face, color: kColorTeal),
                title: Text(kid.name),
                subtitle: _buildKidSubtitle(context, kid),
                trailing: IconButton(
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: l10n.kidsRemoveTooltip,
                  onPressed: () => _confirmRemoveKid(kid),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                l10n.kidsNoneEnrolled,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
