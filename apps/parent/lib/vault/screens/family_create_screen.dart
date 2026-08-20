import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

class FamilyCreateResult {
  const FamilyCreateResult({
    required this.entropy,
    required this.key,
    required this.words,
  });

  final Uint8List entropy;
  final Uint8List key;
  final List<String> words;
}

/// One-time family mnemonic backup (same quiz model as the personal vault).
class FamilyCreateScreen extends StatefulWidget {
  const FamilyCreateScreen({super.key});

  @override
  State<FamilyCreateScreen> createState() => _FamilyCreateScreenState();
}

class _FamilyCreateScreenState extends State<FamilyCreateScreen> {
  Uint8List? _entropy;
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
    final created = await KineticVault.createMnemonic();
    if (!mounted) return;
    setState(() {
      _entropy = created.entropy;
      _words = created.words;
    });
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
    final entropy = _entropy;
    if (words == null || entropy == null) return;
    final ok = KineticVault.quizMatches(
      mnemonic: words,
      indices: _quiz,
      answers: _quizCtrls.map((c) => c.text).toList(),
    );
    if (!ok) {
      setState(
        () => _quizError = 'Niet alle woorden kloppen. Probeer opnieuw.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final key = await KineticVault.deriveAesKey(words.join(' '));
      if (!mounted) return;
      Navigator.of(context).pop(
        FamilyCreateResult(entropy: entropy, key: key, words: words),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _quizError = 'Kon de familiesleutel niet aanmaken: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Familiesleutel' : 'Bevestigen'),
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
            'Schrijf deze 12 woorden op. Ze horen bij de familiesleutel die je '
            'deelt met je partner. We slaan de woorden niet op.',
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
                : const Text('Doorgaan'),
          ),
        ],
      ),
    );
  }
}
