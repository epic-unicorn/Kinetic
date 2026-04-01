import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/personal_note.dart';
import '../services/note_repository.dart';
import 'note_editor_screen.dart';

/// Screen that displays all notes in a scrollable list with create/edit/delete.
class NotesScreen extends StatefulWidget {
  final NoteRepository repo;

  const NotesScreen({super.key, required this.repo});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notities'), centerTitle: false),
      body: StreamBuilder(
        stream: widget.repo.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_outlined, size: 56, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Geen notities',
                    style: TextStyle(color: Colors.white38, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Maak je eerste notitie aan',
                    style: TextStyle(color: Colors.white24),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, i) =>
                _NoteTile(note: notes[i], repo: widget.repo),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final result = await Navigator.of(context).push<PersonalNote?>(
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(repo: widget.repo),
            ),
          );
          if (mounted && result != null) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Notitie opgeslagen')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final PersonalNote note;
  final NoteRepository repo;

  const _NoteTile({required this.note, required this.repo});

  @override
  Widget build(BuildContext context) {
    final preview = note.body.length > 100
        ? '${note.body.substring(0, 100)}…'
        : note.body;

    return ListTile(
      title: Text(note.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (note.remindAt != null) ...[
                Icon(Icons.alarm, size: 14, color: kColorGold),
                const SizedBox(width: 6),
                Text(
                  formatDueDate(note.remindAt!),
                  style: const TextStyle(fontSize: 12, color: kColorGold),
                ),
                const SizedBox(width: 12),
              ],
              if (note.isShared) ...[
                Icon(Icons.lock, size: 14, color: kColorTeal),
                const SizedBox(width: 6),
                const Text(
                  'Gedeeld',
                  style: TextStyle(fontSize: 12, color: kColorTeal),
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () async {
        final result = await Navigator.of(context).push<PersonalNote?>(
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(repo: repo, note: note),
          ),
        );
        if (context.mounted && result != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Notitie opgeslagen')));
        }
      },
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
        ],
        onSelected: (value) {
          if (value == 'delete') {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Verwijderen?'),
                content: const Text('Je kunt dit niet ongedaan maken.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Annuleren'),
                  ),
                  FilledButton(
                    onPressed: () {
                      repo.delete(note.id);
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notitie verwijderd')),
                        );
                      }
                    },
                    child: const Text('Verwijderen'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
