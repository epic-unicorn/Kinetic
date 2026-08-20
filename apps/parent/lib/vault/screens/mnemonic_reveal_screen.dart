import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../vault_biometrics.dart';

/// Confirms the device lock (or a warning) and shows [words].
Future<void> showMnemonicReveal({
  required BuildContext context,
  required String title,
  required Future<List<String>?> Function() loadWords,
  required String missingMessage,
}) async {
  final l10n = AppLocalizations.of(context);
  final words = await loadWords();
  if (!context.mounted) return;
  if (words == null || words.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(missingMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    return;
  }

  final locked = await VaultBiometrics.authenticate(
    reason: l10n.vaultBiometricsReason,
  );
  if (!context.mounted) return;
  if (locked == false) return;
  if (locked == null) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.vaultNoScreenLockTitle),
        content: Text(l10n.vaultNoScreenLockBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vaultShowAnyway),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MnemonicRevealScreen(title: title, words: words),
    ),
  );
}

class MnemonicRevealScreen extends StatelessWidget {
  const MnemonicRevealScreen({
    super.key,
    required this.title,
    required this.words,
  });

  final String title;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.vaultRevealWarning,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: words.length,
                itemBuilder: (context, i) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${i + 1}.  ${words[i]}'),
                      ),
                    ),
                  );
                },
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: words.join(' ')));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.vaultPhraseCopied)),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.commonCopy),
            ),
          ],
        ),
      ),
    );
  }
}
