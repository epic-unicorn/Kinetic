import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vault_biometrics.dart';

/// Confirms the device lock (or a warning) and shows [words].
Future<void> showMnemonicReveal({
  required BuildContext context,
  required String title,
  required Future<List<String>?> Function() loadWords,
  required String missingMessage,
}) async {
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final locked = await VaultBiometrics.authenticate(
    reason: 'Toon de herstelzin op dit apparaat',
  );
  if (!context.mounted) return;
  if (locked == false) return;
  if (locked == null) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geen schermvergrendeling'),
        content: const Text(
          'Dit apparaat heeft geen Face ID, vingerafdruk of pincode. '
          'Iedereen met toegang tot de app kan de woorden zien. Doorgaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Toch tonen'),
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schrijf de woorden opnieuw op papier als je de kopie kwijt bent. '
              'Laat dit scherm niet openstaan.',
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
                  const SnackBar(content: Text('Herstelzin gekopieerd')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Kopiëren'),
            ),
          ],
        ),
      ),
    );
  }
}
