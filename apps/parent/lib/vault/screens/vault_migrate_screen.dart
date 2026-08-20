import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
                l10n.vaultMigrateTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.vaultMigrateBody,
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
                        confirmLabel: l10n.vaultMigrateActivate,
                        headline: l10n.vaultMigrateHeadline,
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
                child: Text(l10n.commonContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
