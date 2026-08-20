import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../sync/webdav_config_repository.dart';
import '../vault_key_rotation.dart';
import '../vault_repository.dart';
import 'vault_welcome_screen.dart';

/// Upgrades a 0.2.x random personal key to a 12-word vault without wiping
/// the local database.
class VaultMigrateScreen extends StatelessWidget {
  const VaultMigrateScreen({
    super.key,
    required this.db,
    required this.configRepo,
    required this.vaultRepo,
    required this.onUnlocked,
  });

  final AppDatabase db;
  final WebDavConfigRepository configRepo;
  final VaultRepository vaultRepo;
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.upgrade,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Nieuwe herstelzin',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Je huidige sleutel is willekeurig (versie 0.2) en kan niet in '
                '12 woorden. Taken en notities op dit apparaat blijven staan. '
                'We maken een nieuwe herstelzin. Bij de volgende sync worden '
                'persoonlijke bestanden opnieuw versleuteld. De familiesleutel '
                'blijft hetzelfde — partner en kinderen hoeven niet opnieuw te '
                'koppelen.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VaultCreateScreen(
                        vaultRepo: vaultRepo,
                        onUnlocked: onUnlocked,
                        confirmLabel: 'Nieuwe herstelzin activeren',
                        headline:
                            'Schrijf deze nieuwe 12 woorden op. De oude sleutel '
                            'werkt daarna niet meer voor WebDAV of een .kvault.',
                        afterUnlock: () async {
                          await markPersonalItemsDirty(db);
                          await rewriteRemoteAfterPersonalKeyRotation(
                            configRepo,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Doorgaan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
