import 'package:flutter/material.dart';

import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';
import 'kids_enrollment_qr_screen.dart';
import 'models/enrolled_kid.dart';

// ---------------------------------------------------------------------------
// KidsSettingsScreen
//
// Manages kids enrollment: shows a QR for the kids app to scan, lists
// enrolled kids and allows removing them.
//
// Available as soon as WebDAV is configured — no partner pairing required.
// Calling open() generates a family key silently if one doesn't exist yet.
// ---------------------------------------------------------------------------

class KidsSettingsScreen extends StatefulWidget {
  final WebDavConfigRepository configRepo;
  final VoidCallback? onConfigSaved;

  const KidsSettingsScreen({
    super.key,
    required this.configRepo,
    this.onConfigSaved,
  });

  @override
  State<KidsSettingsScreen> createState() => _KidsSettingsScreenState();
}

class _KidsSettingsScreenState extends State<KidsSettingsScreen> {
  List<EnrolledKid> _enrolledKids = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final kids = await widget.configRepo.loadEnrolledKids();
    if (mounted) {
      setState(() {
        _enrolledKids = kids;
      });
    }
  }

  Future<void> _enrollKid() async {
    // Ensure a family key exists (generates silently if needed).
    await widget.configRepo.ensureFamilyKey();
    // Reload config so the QR screen has the (possibly new) key.
    final config = await widget.configRepo.load();
    if (!mounted || config == null) return;
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
  }

  Future<void> _confirmRemoveKid(EnrolledKid kid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${kid.name} verwijderen?'),
        content: Text(
          '${kid.name} wordt uit de familielijst verwijderd. '
          'De kinderenapp kan daarna geen familietaken meer ontvangen tenzij opnieuw gekoppeld.',
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
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.configRepo.removeEnrolledKid(kid.id);
    await _loadData();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}-${local.month}-${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kinderen'), centerTitle: false),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.child_care, color: kColorTeal),
            title: const Text('Kinderenapp koppelen'),
            subtitle: const Text('Laat de kinderenapp de QR-code scannen.'),
            trailing: const Icon(Icons.qr_code),
            onTap: _enrollKid,
          ),
          if (_enrolledKids.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'GEKOPPELDE KINDEREN',
                style: TextStyle(
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
                subtitle: Text('Gekoppeld op ${_formatDate(kid.enrolledAt)}'),
                trailing: IconButton(
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Verwijder uit familie',
                  onPressed: () => _confirmRemoveKid(kid),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Nog geen kinderen gekoppeld.',
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
