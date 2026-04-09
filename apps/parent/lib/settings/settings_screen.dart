import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/full_backup_service.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_header.dart';
import '../theme/app_themes.dart';
import '../main.dart';
import 'kids_settings_screen.dart';
import 'partner_settings_screen.dart';
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
  SyncConfig? _config;
  bool _partnerPaired = false;
  int _enrolledKidsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.configRepo.load();
    final paired = await widget.configRepo.isPartnerPaired();
    final kids = await widget.configRepo.loadEnrolledKids();
    if (mounted)
      setState(() {
        _config = config;
        _partnerPaired = paired;
        _enrolledKidsCount = kids.length;
      });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _config != null;
    return Scaffold(
      appBar: AppBar(
        title: AppHeader(title: 'Instellingen', centerTitle: false),
        centerTitle: false,
      ),
      body: ValueListenableBuilder<AppTheme>(
        valueListenable: themeNotifier,
        builder: (context, currentTheme, _) {
          final iconColor = kColorTeal;
          return ListView(
            children: [
              const _SectionHeader(label: 'Uiterlijk'),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: iconColor),
                title: const Text('Thema'),
                subtitle: Text(currentTheme.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSelector(context),
              ),
              const _SectionHeader(label: 'Synchronisatie'),
              ListTile(
                leading: Icon(Icons.cloud_outlined, color: iconColor),
                title: const Text('WebDAV configureren'),
                subtitle: Text(
                  isConnected
                      ? 'Verbonden'
                      : 'Verbind met een Nextcloud- of WebDAV-server',
                ),
                trailing: isConnected
                    ? Icon(Icons.check_circle, color: iconColor)
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WebDavSetupScreen(
                        db: widget.db,
                        configRepo: widget.configRepo,
                        onConfigSaved: widget.onConfigSaved,
                      ),
                    ),
                  );
                  _loadConfig();
                },
              ),
              if (isConnected) ...[
                const _SectionHeader(label: 'Familie'),
                ListTile(
                  leading: Icon(Icons.people_outline, color: iconColor),
                  title: const Text('Partner'),
                  subtitle: Text(
                    _partnerPaired
                        ? 'Partner gekoppeld'
                        : 'Koppel met je partner',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PartnerSettingsScreen(
                          db: widget.db,
                          configRepo: widget.configRepo,
                          onConfigSaved: widget.onConfigSaved,
                        ),
                      ),
                    );
                    _loadConfig();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.child_care, color: iconColor),
                  title: const Text('Kinderen'),
                  subtitle: Text(
                    _enrolledKidsCount > 0
                        ? '$_enrolledKidsCount kind${_enrolledKidsCount == 1 ? '' : 'eren'} gekoppeld'
                        : 'Koppel de kinderenapp',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KidsSettingsScreen(
                          configRepo: widget.configRepo,
                          onConfigSaved: widget.onConfigSaved,
                        ),
                      ),
                    );
                    _loadConfig();
                  },
                ),
              ],
              const _SectionHeader(label: 'Back-up & Herstel'),
              ListTile(
                leading: Icon(Icons.backup_outlined, color: iconColor),
                title: const Text('Back-up exporteren'),
                subtitle: const Text(
                  'Exporteer database en sleutel in één bestand',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportFullBackup(),
              ),
              ListTile(
                leading: Icon(Icons.restore_outlined, color: iconColor),
                title: const Text('Back-up importeren'),
                subtitle: const Text('Herstel vanuit een back-upbestand'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importFullBackup(),
              ),
            ],
          );
        },
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

  // ---------------------------------------------------------------------------
  // Combined backup export (database + personal key in one .kbak2 package)
  // ---------------------------------------------------------------------------

  Future<void> _exportFullBackup() async {
    final key =
        _config?.personalKeyBytes ??
        await widget.configRepo.loadPersonalKeyBytes();
    if (key == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geen persoonlijke sleutel gevonden. Configureer eerst WebDAV.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Exporteren…'),
          ],
        ),
      ),
    );

    try {
      final bytes = await FullBackupService.exportToBytes(
        widget.db,
        key,
        usernameHint: _config?.username ?? '',
      );
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'kinetic_backup_$stamp.kbak2';

      if (!mounted) return;
      Navigator.of(context).pop();

      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );

      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Back-up opgeslagen: $savedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij exporteren: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Combined backup import
  // ---------------------------------------------------------------------------

  Future<void> _importFullBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon het bestand niet lezen.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Back-up importeren?'),
        content: const Text(
          'Dit vervangt al je huidige taken, notities en persoonlijke sleutel '
          'met de inhoud van het back-upbestand. Dit kan niet ongedaan worden gemaakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importeren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Importeren…'),
          ],
        ),
      ),
    );

    try {
      await FullBackupService.importFromBytes(
        widget.db,
        widget.configRepo,
        fileBytes,
      );
      if (mounted) {
        Navigator.of(context).pop();
        await _loadConfig();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Back-up succesvol hersteld.')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ongeldig back-upbestand: $e')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij importeren: $e')));
      }
    }
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

  Future<void> _handleMigration(
    String serverUrl,
    String username,
    String password,
    Uint8List personalKey,
  ) async {
    try {
      debugPrint('[Migration] Starting migration check...');

      final client = WebDavClient(
        baseUrl: serverUrl,
        username: username,
        password: password,
      );

      try {
        final config = SyncConfig(
          serverUrl: serverUrl,
          username: username,
          password: password,
          parentId: '',
          personalKeyBytes: personalKey,
          familyKeyBytes: null,
        );

        final service = WebDavSyncService(client: client, config: config);

        // Check if there are any files on the server (before trying to decrypt)
        debugPrint('[Migration] Checking for remote files...');
        final tasksPath = '/kinetic/$username/tasks';
        final notesPath = '/kinetic/$username/notes';

        final taskFiles = await _listServerFiles(client, tasksPath);
        final noteFiles = await _listServerFiles(client, notesPath);

        debugPrint(
          '[Migration] Found ${taskFiles.length} task files and ${noteFiles.length} note files',
        );

        if (taskFiles.isEmpty && noteFiles.isEmpty) {
          // No existing data, nothing to migrate
          debugPrint('[Migration] No existing data found, skipping migration');
          return;
        }

        // There are files on the server - ask user what to do
        debugPrint(
          '[Migration] Found existing files, showing migration dialog',
        );
        if (!mounted) {
          debugPrint('[Migration] Widget not mounted, aborting');
          return;
        }

        final shouldImport = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Bestaande gegevens gevonden'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Er zijn bestaande taken en notities op de WebDAV-server gevonden:',
                ),
                const SizedBox(height: 12),
                Text('  • Taakbestanden: ${taskFiles.length}'),
                Text('  • Notitiebstanden: ${noteFiles.length}'),
                const SizedBox(height: 16),
                const Text(
                  'Opmerking: Als je van een ander apparaat komt, kunnen de gegevens niet automatisch worden gedecodeerd met je nieuwe sleutel.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wat wil je doen?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Opschonen (verwijderen)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Importeren'),
              ),
            ],
          ),
        );

        debugPrint('[Migration] User choice: shouldImport=$shouldImport');

        if (shouldImport ?? false) {
          // Try to import - will only import decryptable items
          debugPrint(
            '[Migration] User chose to import, attempting to read and decrypt data',
          );
          try {
            final remoteTasks = await service.pullTasks();
            final remoteNotes = await service.pullNotes();
            debugPrint(
              '[Migration] Successfully decrypted ${remoteTasks.length} tasks and ${remoteNotes.length} notes',
            );

            if (remoteTasks.isNotEmpty || remoteNotes.isNotEmpty) {
              await _importRemoteData(remoteTasks, remoteNotes);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Kon de bestaande gegevens niet decoderen. Ze zijn mogelijk met een ander wachtwoord versleuteld.',
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('[Migration] Error during import: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fout bij importeren: $e')),
              );
            }
          }
        } else {
          // Clean up: delete remote files
          debugPrint(
            '[Migration] User chose to clean up, deleting remote files',
          );
          await _cleanupRemoteFiles(client, taskFiles, noteFiles);
        }
      } finally {
        client.dispose();
      }
    } catch (e, st) {
      // Log error but don't block the configuration save
      debugPrint('[Migration] Error during migration: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migratiecontrole mislukt: $e')));
      }
    }
  }

  Future<List<String>> _listServerFiles(
    WebDavClient client,
    String path,
  ) async {
    try {
      // Use PROPFIND to list files without encryption/decryption
      final entries = await client.propfind(path);
      return entries.map((e) => e.href).toList();
    } catch (e) {
      debugPrint('[Migration] Error listing $path: $e');
      return [];
    }
  }

  Future<void> _cleanupRemoteFiles(
    WebDavClient client,
    List<String> taskFiles,
    List<String> noteFiles,
  ) async {
    try {
      // Delete task files
      for (final file in taskFiles) {
        try {
          await client.delete(file);
        } catch (e) {
          debugPrint('[Migration] Error deleting task file $file: $e');
        }
      }

      // Delete note files
      for (final file in noteFiles) {
        try {
          await client.delete(file);
        } catch (e) {
          debugPrint('[Migration] Error deleting note file $file: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${taskFiles.length + noteFiles.length} bestanden verwijderd.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij opschonen: $e')));
      }
    }
  }

  Future<void> _importRemoteData(
    List<ICalTask> remoteTasks,
    List<ICalNote> remoteNotes,
  ) async {
    try {
      // Import tasks
      for (final remoteTask in remoteTasks) {
        final existingTask = await (widget.db.select(
          widget.db.personalTasks,
        )..where((t) => t.id.equals(remoteTask.uid))).getSingleOrNull();

        if (existingTask == null) {
          // New task from remote
          final isCompleted = remoteTask.status == ICalTaskStatus.completed;
          await widget.db
              .into(widget.db.personalTasks)
              .insert(
                PersonalTasksCompanion(
                  id: Value(remoteTask.uid),
                  title: Value(remoteTask.summary),
                  notes: Value(remoteTask.description),
                  dueDate: Value(remoteTask.dueAt),
                  isCompleted: Value(isCompleted),
                  completedAt: Value(isCompleted ? DateTime.now() : null),
                  createdAt: Value(remoteTask.createdAt),
                  updatedAt: Value(remoteTask.updatedAt),
                  recurrenceRule: Value(remoteTask.rrule),
                  syncState: const Value('clean'),
                ),
              );
        }
      }

      // Import notes
      for (final remoteNote in remoteNotes) {
        final existingNote = await (widget.db.select(
          widget.db.personalNotes,
        )..where((n) => n.id.equals(remoteNote.uid))).getSingleOrNull();

        if (existingNote == null) {
          // New note from remote
          await widget.db
              .into(widget.db.personalNotes)
              .insert(
                PersonalNotesCompanion(
                  id: Value(remoteNote.uid),
                  title: Value(remoteNote.summary),
                  body: Value(remoteNote.description ?? ''),
                  isShared: Value(remoteNote.isShared),
                  createdAt: Value(remoteNote.createdAt),
                  updatedAt: Value(remoteNote.updatedAt),
                  remindAt: Value(remoteNote.remindAt),
                  syncState: const Value('clean'),
                ),
              );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${remoteTasks.length + remoteNotes.length} items geïmporteerd.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij importeren: $e')));
      }
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

      final bool isSameAccount =
          _existing != null &&
          _existing!.username == username &&
          _existing!.serverUrl == serverUrl;

      // Only generate keys the first time; preserve existing keys on an edit.
      final Uint8List personalKey;
      if (isSameAccount) {
        // Reuse existing personal key. Never overwrite the family key here —
        // it is set exclusively via the QR exchange flow.
        personalKey = _existing!.personalKeyBytes;
      } else {
        // New account — generate only the personal key.
        // Family key is NOT generated here; it is exchanged via QR pairing.
        personalKey = KineticEncryption.generatePersonalKey();
      }

      // Reuse existing parentId, or generate a stable UUID for a new account.
      final String parentId = (isSameAccount && _existing!.parentId.isNotEmpty)
          ? _existing!.parentId
          : const Uuid().v4();

      // Preserve any previously exchanged family key when editing credentials.
      final existingFamilyKey = isSameAccount
          ? _existing!.familyKeyBytes
          : null;

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
          parentId: parentId,
          personalKeyBytes: personalKey,
          familyKeyBytes: existingFamilyKey,
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

        // Check for existing remote data and ask user what to do
        if (mounted) {
          await _handleMigration(serverUrl, username, password, personalKey);
        }
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
