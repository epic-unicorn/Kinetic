import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';
import '../main.dart';
import 'settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase db;
  final WebDavConfigRepository configRepo;
  final SettingsRepository settingsRepo;
  final VoidCallback? onConfigSaved;

  const SettingsScreen({
    super.key,
    required this.db,
    required this.configRepo,
    required this.settingsRepo,
    this.onConfigSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen'), centerTitle: false),
      body: ListView(
        children: [
          const _SectionHeader(label: 'Uiterlijk'),
          ValueListenableBuilder<AppTheme>(
            valueListenable: themeNotifier,
            builder: (context, currentTheme, _) => ListTile(
              leading: const Icon(Icons.palette_outlined, color: kColorTeal),
              title: const Text('Thema'),
              subtitle: Text(currentTheme.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context),
            ),
          ),
          const _SectionHeader(label: 'Synchronisatie'),
          FutureBuilder<SyncConfig?>(
            future: widget.configRepo.load(),
            builder: (context, snapshot) {
              final isConfigured = snapshot.data != null;
              return ListTile(
                leading: const Icon(Icons.cloud_outlined, color: kColorTeal),
                title: const Text('WebDAV configureren'),
                subtitle: Text(
                  isConfigured
                      ? 'Verbonden'
                      : 'Verbind met een Nextcloud- of WebDAV-server',
                ),
                trailing: isConfigured
                    ? const Icon(Icons.check_circle, color: kColorTeal)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WebDavSetupScreen(
                      db: widget.db,
                      configRepo: widget.configRepo,
                      onConfigSaved: widget.onConfigSaved,
                    ),
                  ),
                ),
              );
            },
          ),
          const _SectionHeader(label: 'Over'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: kColorTeal),
            title: const Text('Kinetic Link'),
            subtitle: const Text('Versie 2.0.0'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thema kiezen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final theme in AppTheme.values)
              RadioListTile<AppTheme>(
                title: Text(theme.label),
                value: theme,
                groupValue: themeNotifier.value,
                onChanged: (newTheme) async {
                  if (newTheme != null) {
                    themeNotifier.value = newTheme;
                    await widget.settingsRepo.saveTheme(newTheme);
                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WebDAV setup screen
// ---------------------------------------------------------------------------

class WebDavSetupScreen extends StatefulWidget {
  final AppDatabase db;
  final WebDavConfigRepository configRepo;
  final VoidCallback? onConfigSaved;

  const WebDavSetupScreen({
    super.key,
    required this.db,
    required this.configRepo,
    this.onConfigSaved,
  });

  @override
  State<WebDavSetupScreen> createState() => _WebDavSetupScreenState();
}

class _WebDavSetupScreenState extends State<WebDavSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _testing = false;
  bool _saving = false;
  String? _testResult; // null=untested, 'ok', or error message
  SyncConfig? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final config = await widget.configRepo.load();
    if (config != null && mounted) {
      setState(() {
        _existing = config;
        _urlCtrl.text = config.serverUrl;
        _userCtrl.text = config.username;
        _passCtrl.text = config.password;
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final error = await WebDavEnrollment.testConnection(
      _urlCtrl.text.trim(),
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = error ?? 'ok';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_testResult != 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test de verbinding eerst voordat je opslaat.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final serverUrl = _urlCtrl.text.trim();
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;

      // Only generate keys the first time; preserve existing keys on an edit.
      final Uint8List personalKey;
      final Uint8List familyKey;
      if (_existing != null &&
          _existing!.username == username &&
          _existing!.serverUrl == serverUrl) {
        // Reuse existing keys.
        personalKey = _existing!.personalKeyBytes;
        familyKey =
            _existing!.familyKeyBytes ?? KineticEncryption.generateFamilyKey();
      } else {
        // New account — generate fresh keys.
        personalKey = KineticEncryption.generatePersonalKey();
        familyKey = KineticEncryption.generateFamilyKey();
      }

      // Always ensure directories exist (needed for both new and updated configs)
      final client = WebDavClient(
        baseUrl: serverUrl,
        username: username,
        password: password,
      );
      try {
        await WebDavEnrollment.setupDirectories(client, username);
      } finally {
        client.dispose();
      }

      await widget.configRepo.save(
        SyncConfig(
          serverUrl: serverUrl,
          username: username,
          password: password,
          personalKeyBytes: personalKey,
          familyKeyBytes: familyKey,
        ),
      );

      // Mark all existing non-deleted items as dirty so they'll be synced to the server
      if (_existing == null) {
        // Only do this on first-time setup, not on edits
        // Include items with syncState='clean' or NULL (for items created before sync was added)
        await (widget.db.update(
              widget.db.personalTasks,
            )..where((t) => t.syncState.equals('clean') | t.syncState.isNull()))
            .write(PersonalTasksCompanion(syncState: const Value('dirty')));
        await (widget.db.update(
              widget.db.personalNotes,
            )..where((n) => n.syncState.equals('clean') | n.syncState.isNull()))
            .write(PersonalNotesCompanion(syncState: const Value('dirty')));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebDAV-configuratie opgeslagen.')),
        );
        widget.onConfigSaved?.call();
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportRecoveryKey() async {
    if (_existing == null) return;
    final json = KineticEncryption.exportRecoveryJson(
      _existing!.personalKeyBytes,
      _existing!.username,
    );
    // Display in a dialog for the user to manually copy/save.
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Herstelsleutel'),
        content: SingleChildScrollView(
          child: SelectableText(
            json,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

  Future<void> _exportFamilyKey() async {
    if (_existing == null) return;
    final familyKey = _existing!.familyKeyBytes;
    if (familyKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nog geen familiesleutel ingesteld.')),
      );
      return;
    }
    final json = KineticEncryption.exportFamilyKeyJson(
      familyKey,
      _existing!.username,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Familiesleutel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deel deze sleutel met je partner. '
                'Bewaar hem veilig — iedereen met deze sleutel kan '
                'gedeelde taken en notities lezen.',
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

  Future<void> _importFamilyKey() async {
    if (_existing == null) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Familiesleutel importeren'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plak hier de familiesleutel-JSON die je partner heeft geëxporteerd.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "version": 1,\n  ...\n}',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Importeren'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final familyKey = KineticEncryption.importFamilyKeyJson(
        controller.text.trim(),
      );
      await widget.configRepo.saveFamilyKey(familyKey);
      // Update in-memory config.
      setState(() {
        _existing = _existing!.withFamilyKey(familyKey);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Familiesleutel geïmporteerd.')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ongeldige sleutel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV instellen'), centerTitle: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Server URL
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Server-URL',
                hintText: 'https://nextcloud.example.com/remote.php/dav',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() => _testResult = null),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vul de server-URL in';
                }
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'Ongeldige URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Username
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Gebruikersnaam',
                prefixIcon: Icon(Icons.person_outline),
              ),
              autocorrect: false,
              onChanged: (_) => setState(() => _testResult = null),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vul de gebruikersnaam in'
                  : null,
            ),
            const SizedBox(height: 16),
            // Password
            TextFormField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Wachtwoord',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() => _testResult = null),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vul het wachtwoord in' : null,
            ),
            const SizedBox(height: 28),
            // Test connection button
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(
                _testing ? 'Verbinding testen…' : 'Verbinding testen',
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              _TestResultBanner(result: _testResult!),
            ],
            const SizedBox(height: 16),
            // Save button
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Opslaan…' : 'Opslaan'),
            ),
            if (_existing != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.key_outlined, color: kColorGold),
                title: const Text('Herstelsleutel exporteren'),
                subtitle: const Text(
                  'Bewaar dit bestand veilig — het is de enige manier om '
                  'je data te herstellen als je dit apparaat kwijtraakt.',
                ),
                onTap: _exportRecoveryKey,
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: kColorTeal),
                title: const Text('Familiesleutel exporteren'),
                subtitle: const Text(
                  'Deel deze sleutel met je partner zodat jullie elkaars '
                  'gedeelde taken en notities kunnen lezen.',
                ),
                onTap: _exportFamilyKey,
              ),
              ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: kColorTeal,
                ),
                title: const Text('Familiesleutel importeren'),
                subtitle: const Text(
                  'Plak de familiesleutel die je van je partner hebt ontvangen.',
                ),
                onTap: _importFamilyKey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test result banner
// ---------------------------------------------------------------------------

class _TestResultBanner extends StatelessWidget {
  final String result; // 'ok' or error message

  const _TestResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final isOk = result == 'ok';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOk
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk ? Colors.green : Colors.redAccent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.error_outline,
            color: isOk ? Colors.green : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOk ? 'Verbinding geslaagd' : result,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isOk ? Colors.green : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
