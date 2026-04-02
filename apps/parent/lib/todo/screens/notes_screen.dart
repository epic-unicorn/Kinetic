import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_header.dart';
import '../../theme/app_theme.dart';
import '../models/personal_note.dart';
import '../services/note_repository.dart';
import 'note_editor_screen.dart';

/// Screen that displays all notes in a scrollable list with create/edit/delete.
class NotesScreen extends StatefulWidget {
  final NoteRepository repo;
  final ValueNotifier<SyncStatus>? syncStatus;
  final ValueNotifier<bool>? hasFamilyKey;

  const NotesScreen({
    super.key,
    required this.repo,
    this.syncStatus,
    this.hasFamilyKey,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppHeader(title: 'Notities', centerTitle: false),
        centerTitle: false,
        actions: [
          if (widget.syncStatus != null)
            ValueListenableBuilder<SyncStatus>(
              valueListenable: widget.syncStatus!,
              builder: (context, status, _) => switch (status) {
                SyncStatus.syncing => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                SyncStatus.error => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.sync_problem_outlined),
                ),
                SyncStatus.idle => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.cloud_done_outlined),
                ),
              },
            ),
        ],
      ),
      body: StreamBuilder(
        stream: widget.repo.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fout bij laden notities',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            final scheme = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 56,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Geen notities',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maak je eerste notitie aan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ValueListenableBuilder<bool>(
            valueListenable: widget.hasFamilyKey ?? ValueNotifier(false),
            builder: (context, paired, _) => ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _NoteTile(
                note: notes[i],
                repo: widget.repo,
                showSharedBadge: paired,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final result = await Navigator.of(context).push<PersonalNote?>(
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(
                repo: widget.repo,
                hasFamilyKey: widget.hasFamilyKey?.value ?? false,
              ),
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
  final bool showSharedBadge;

  const _NoteTile({
    required this.note,
    required this.repo,
    this.showSharedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final preview = note.body.length > 100
        ? '${note.body.substring(0, 100)}…'
        : note.body;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(note.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (note.remindAt != null) ...[
                Icon(Icons.alarm, size: 14, color: kColorGold),
                const SizedBox(width: 8),
                Text(
                  formatDueDate(note.remindAt!),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: kColorGold),
                ),
                const SizedBox(width: 16),
              ],
              if (note.isShared && showSharedBadge) ...[
                Icon(Icons.lock, size: 14, color: kColorTeal),
                const SizedBox(width: 8),
                Text(
                  'Gedeeld',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: kColorTeal),
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () async {
        final result = await Navigator.of(context).push<PersonalNote?>(
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(
              repo: repo,
              note: note,
              hasFamilyKey: showSharedBadge,
            ),
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
                    onPressed: () async {
                      try {
                        await repo.delete(note.id);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notitie verwijderd')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fout bij verwijderen: $e')),
                          );
                        }
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
