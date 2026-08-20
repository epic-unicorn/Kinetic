import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../settings/settings_repository.dart';
import '../sync/webdav_config_repository.dart';
import 'screens/vault_migrate_screen.dart';
import 'screens/vault_welcome_screen.dart';
import 'vault_repository.dart';

/// Blocks the parent app until a personal vault exists on this device.
class VaultGate extends StatefulWidget {
  const VaultGate({
    super.key,
    required this.db,
    required this.settingsRepo,
    required this.readyBuilder,
  });

  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final WidgetBuilder readyBuilder;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  late final SecureKeyValueStore _store;
  late final WebDavConfigRepository _configRepo;
  late final VaultRepository _vaultRepo;
  bool? _ready;
  bool _migrate = false;

  @override
  void initState() {
    super.initState();
    _store = FlutterSecureKeyValueStore();
    _configRepo = WebDavConfigRepository(_store);
    _vaultRepo = VaultRepository(_store, _configRepo);
    _load();
  }

  Future<void> _load() async {
    final ready = await _vaultRepo.isReady();
    final migrate = await _vaultRepo.needsMigration();
    if (mounted) {
      setState(() {
        _ready = ready;
        _migrate = migrate;
      });
    }
  }

  void _onUnlocked() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _ready = true;
      _migrate = false;
    });
  }

  void _onNeedsMigration() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _ready = false;
      _migrate = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ready == true) {
      return widget.readyBuilder(context);
    }
    if (_migrate) {
      return VaultMigrateScreen(
        db: widget.db,
        configRepo: _configRepo,
        vaultRepo: _vaultRepo,
        onUnlocked: _onUnlocked,
      );
    }
    return VaultWelcomeScreen(
      db: widget.db,
      settingsRepo: widget.settingsRepo,
      configRepo: _configRepo,
      vaultRepo: _vaultRepo,
      onUnlocked: _onUnlocked,
      onNeedsMigration: _onNeedsMigration,
    );
  }
}
