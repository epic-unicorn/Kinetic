import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../../db/app_database.dart';
import '../../db/full_backup_service.dart';
import '../../main.dart';
import '../../settings/settings_repository.dart';
import '../../sync/webdav_config_repository.dart';
import '../vault_repository.dart';
import 'vault_restore_screen.dart';

class VaultWelcomeScreen extends StatelessWidget {
  const VaultWelcomeScreen({
    super.key,
    required this.db,
    required this.settingsRepo,
    required this.configRepo,
    required this.vaultRepo,
    required this.onUnlocked,
    required this.onNeedsMigration,
  });

  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final WebDavConfigRepository configRepo;
  final VaultRepository vaultRepo;
  final VoidCallback onUnlocked;
  final VoidCallback onNeedsMigration;

  Future<void> _importLegacyBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon het bestand niet lezen.')),
      );
      return;
    }
    try {
      await FullBackupService.importFromBytes(
        db,
        configRepo,
        bytes,
        settingsRepo: settingsRepo,
        onThemeRestored: (theme) => themeNotifier.value = theme,
      );
      onNeedsMigration();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ongeldige oude back-up: $e')),
      );
    }
  }

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
                Icons.lock_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Jouw kluis',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Kinetic Link bewaart taken en notities met een herstelzin van '
                '12 woorden. Schrijf die zin op papier. Op dit apparaat kun je '
                'hem later opnieuw tonen (met schermvergrendeling).',
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
                      ),
                    ),
                  );
                },
                child: const Text('Nieuwe kluis'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VaultRestoreScreen(
                        db: db,
                        settingsRepo: settingsRepo,
                        configRepo: configRepo,
                        vaultRepo: vaultRepo,
                        onUnlocked: onUnlocked,
                      ),
                    ),
                  );
                },
                child: const Text('Kluis herstellen'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _importLegacyBackup(context),
                child: const Text('Oude back-up (.kbak2)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultCreateScreen extends StatefulWidget {
  const VaultCreateScreen({
    super.key,
    required this.vaultRepo,
    required this.onUnlocked,
    this.headline,
    this.confirmLabel = 'Kluis aanmaken',
    this.afterUnlock,
  });

  final VaultRepository vaultRepo;
  final VoidCallback onUnlocked;
  final String? headline;
  final String confirmLabel;
  final Future<void> Function()? afterUnlock;

  @override
  State<VaultCreateScreen> createState() => _VaultCreateScreenState();
}

class _VaultCreateScreenState extends State<VaultCreateScreen> {
  List<String>? _words;
  List<int> _quiz = const [];
  final _quizCtrls = List.generate(3, (_) => TextEditingController());
  int _step = 0;
  bool _busy = false;
  String? _quizError;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    for (final c in _quizCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    final words = await KineticVault.generateMnemonic();
    if (!mounted) return;
    setState(() => _words = words);
  }

  void _startQuiz() {
    final words = _words;
    if (words == null) return;
    setState(() {
      _quiz = KineticVault.pickQuizIndices();
      _quizError = null;
      for (final c in _quizCtrls) {
        c.clear();
      }
      _step = 1;
    });
  }

  Future<void> _confirmQuiz() async {
    final words = _words;
    if (words == null) return;
    final answers = _quizCtrls.map((c) => c.text).toList();
    final ok = KineticVault.quizMatches(
      mnemonic: words,
      indices: _quiz,
      answers: answers,
    );
    if (!ok) {
      setState(() => _quizError = 'Niet alle woorden kloppen. Probeer opnieuw.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.vaultRepo.unlockWithPhrase(words.join(' '));
      await widget.afterUnlock?.call();
      if (!mounted) return;
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _quizError = 'Kon de kluis niet aanmaken: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Herstelzin' : 'Bevestigen'),
      ),
      body: words == null
          ? const Center(child: CircularProgressIndicator())
          : _step == 0
          ? _buildShowWords(context, words)
          : _buildQuiz(context),
    );
  }

  Widget _buildShowWords(BuildContext context, List<String> words) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.headline ??
                'Schrijf deze 12 woorden op papier en bewaar ze veilig. '
                    'Zonder deze zin kun je de kluis niet op een nieuw apparaat herstellen.',
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
          FilledButton(
            onPressed: _startQuiz,
            child: const Text('Ik heb ze opgeschreven'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vul de gevraagde woorden in om te bevestigen dat je de zin hebt bewaard.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _quiz.length; i++) ...[
            TextFormField(
              controller: _quizCtrls[i],
              decoration: InputDecoration(
                labelText: 'Woord ${_quiz[i] + 1}',
              ),
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: i == _quiz.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ],
          if (_quizError != null)
            Text(
              _quizError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const Spacer(),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _step = 0;
                    _quizError = null;
                  }),
            child: const Text('Terug naar de woorden'),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirmQuiz,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
