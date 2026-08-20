import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../db/full_backup_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../main.dart';
import '../../settings/settings_repository.dart';
import '../../sync/webdav_config_repository.dart';
import '../family_vault_sync.dart';
import '../vault_repository.dart';
import '../widgets/mnemonic_phrase_field.dart';

class VaultRestoreScreen extends StatefulWidget {
  const VaultRestoreScreen({
    super.key,
    required this.db,
    required this.settingsRepo,
    required this.configRepo,
    required this.vaultRepo,
    required this.onUnlocked,
  });

  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final WebDavConfigRepository configRepo;
  final VaultRepository vaultRepo;
  final VoidCallback onUnlocked;

  @override
  State<VaultRestoreScreen> createState() => _VaultRestoreScreenState();
}

class _VaultRestoreScreenState extends State<VaultRestoreScreen> {
  _RestorePath? _path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_path == _RestorePath.file) {
      return _RestoreFileScreen(
        db: widget.db,
        settingsRepo: widget.settingsRepo,
        vaultRepo: widget.vaultRepo,
        onBack: () => setState(() => _path = null),
        onUnlocked: widget.onUnlocked,
      );
    }
    if (_path == _RestorePath.webdav) {
      return _RestoreWebDavScreen(
        configRepo: widget.configRepo,
        vaultRepo: widget.vaultRepo,
        onBack: () => setState(() => _path = null),
        onUnlocked: widget.onUnlocked,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultRestoreTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.vaultRestoreIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l10n.vaultRestoreFromFile),
            subtitle: Text(l10n.vaultRestoreFromFileSubtitle),
            onTap: () => setState(() => _path = _RestorePath.file),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.vaultRestoreFromWebDav),
            subtitle: Text(l10n.vaultRestoreFromWebDavSubtitle),
            onTap: () => setState(() => _path = _RestorePath.webdav),
          ),
        ],
      ),
    );
  }
}

enum _RestorePath { file, webdav }

class _RestoreFileScreen extends StatefulWidget {
  const _RestoreFileScreen({
    required this.db,
    required this.settingsRepo,
    required this.vaultRepo,
    required this.onBack,
    required this.onUnlocked,
  });

  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final VaultRepository vaultRepo;
  final VoidCallback onBack;
  final VoidCallback onUnlocked;

  @override
  State<_RestoreFileScreen> createState() => _RestoreFileScreenState();
}

class _RestoreFileScreenState extends State<_RestoreFileScreen> {
  final _phraseCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await KineticVault.deriveAesKey(_phraseCtrl.text);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw FormatException(l10n.vaultCouldNotReadFile);
      }
      await FullBackupService.importVaultFromBytes(
        widget.db,
        bytes,
        key,
        settingsRepo: widget.settingsRepo,
        onThemeRestored: (theme) => themeNotifier.value = theme,
      );
      await widget.vaultRepo.unlockWithPhrase(_phraseCtrl.text);
      if (!mounted) return;
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vaultRestoreFileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.vaultRestoreFileBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            MnemonicPhraseField(controller: _phraseCtrl),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _restore,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.vaultChooseFileAndRestore),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreWebDavScreen extends StatefulWidget {
  const _RestoreWebDavScreen({
    required this.configRepo,
    required this.vaultRepo,
    required this.onBack,
    required this.onUnlocked,
  });

  final WebDavConfigRepository configRepo;
  final VaultRepository vaultRepo;
  final VoidCallback onBack;
  final VoidCallback onUnlocked;

  @override
  State<_RestoreWebDavScreen> createState() => _RestoreWebDavScreenState();
}

class _RestoreWebDavScreenState extends State<_RestoreWebDavScreen> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phraseCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _phraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final serverUrl = _urlCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    try {
      final key = await KineticVault.deriveAesKey(_phraseCtrl.text);
      final connError = await WebDavEnrollment.testConnection(
        serverUrl,
        username,
        password,
      );
      if (connError != null) {
        throw FormatException(connError);
      }
      final client = WebDavClient(
        baseUrl: serverUrl,
        username: username,
        password: password,
      );
      try {
        final status = await KineticVaultRemote.probe(
          client: client,
          username: username,
          key: key,
        );
        switch (status) {
          case VaultMetaStatus.missing:
            throw FormatException(l10n.vaultNoVaultOnServer);
          case VaultMetaStatus.wrongPhrase:
            throw FormatException(l10n.vaultPhraseMismatchServer);
          case VaultMetaStatus.unlocked:
            break;
        }
        await WebDavEnrollment.setupDirectories(client, username);
        await FamilyVaultSync.pullIfPresent(
          client: client,
          username: username,
          personalKey: key,
          configRepo: widget.configRepo,
        );
      } finally {
        client.dispose();
      }

      await widget.configRepo.save(
        SyncConfig(
          serverUrl: serverUrl,
          username: username,
          password: password,
          parentId: const Uuid().v4(),
          personalKeyBytes: key,
        ),
      );
      await widget.vaultRepo.unlockWithPhrase(_phraseCtrl.text);
      if (!mounted) return;
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vaultRestoreWebDavTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : widget.onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.vaultRestoreWebDavBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: l10n.vaultServerUrl,
              prefixIcon: const Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: InputDecoration(
              labelText: l10n.vaultUsername,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            decoration: InputDecoration(
              labelText: l10n.vaultPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            obscureText: _obscure,
          ),
          const SizedBox(height: 16),
          MnemonicPhraseField(controller: _phraseCtrl),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _restore,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.vaultUnlock),
          ),
        ],
      ),
    );
  }
}
