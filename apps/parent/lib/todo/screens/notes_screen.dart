import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_header.dart';
import '../../theme/app_theme.dart';
import '../models/personal_note.dart';
import '../services/note_repository.dart';
import '../widgets/category_sheet.dart';
import 'note_editor_screen.dart';

/// Screen that displays all notes in a scrollable list with create/edit/delete.
class NotesScreen extends StatefulWidget {
  final NoteRepository repo;
  final ValueNotifier<SyncStatus>? syncStatus;
  final ValueNotifier<bool>? hasFamilyKey;
  final VoidCallback? onSyncRetry;

  const NotesScreen({
    super.key,
    required this.repo,
    this.syncStatus,
    this.hasFamilyKey,
    this.onSyncRetry,
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
              builder: (context, status, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: switch (status) {
                  SyncStatus.syncing => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SyncStatus.error => GestureDetector(
                    onTap: widget.onSyncRetry,
                    child: Tooltip(
                      message: 'Sync mislukt, tap om opnieuw te proberen.',
                      child: Icon(
                        Icons.sync_problem_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  SyncStatus.idle => const Icon(Icons.cloud_done_outlined),
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).push<PersonalNote?>(
                MaterialPageRoute(
                  builder: (_) => NoteEditorScreen(
                    repo: widget.repo,
                    hasFamilyKey: widget.hasFamilyKey?.value ?? false,
                  ),
                ),
              );
              if (context.mounted && result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notitie opgeslagen')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PersonalNote>>(
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
            builder: (context, paired, _) {
              return _NoteGroupedList(
                notes: notes,
                repo: widget.repo,
                showSharedBadge: paired,
              );
            },
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

// ---------------------------------------------------------------------------
// Grouped + draggable notes list
// ---------------------------------------------------------------------------

sealed class _NoteListItem {}

class _NoteHeaderItem extends _NoteListItem {
  final String? category;
  _NoteHeaderItem({required this.category});
}

class _NoteDataItem extends _NoteListItem {
  final PersonalNote note;
  _NoteDataItem({required this.note});
}

class _NoteGroupedList extends StatefulWidget {
  final List<PersonalNote> notes;
  final NoteRepository repo;
  final bool showSharedBadge;

  const _NoteGroupedList({
    required this.notes,
    required this.repo,
    required this.showSharedBadge,
  });

  @override
  State<_NoteGroupedList> createState() => _NoteGroupedListState();
}

class _NoteGroupedListState extends State<_NoteGroupedList> {
  @override
  Widget build(BuildContext context) {
    // Group notes by category
    final groups = <String?, List<PersonalNote>>{};
    for (final n in widget.notes) {
      groups.putIfAbsent(n.category, () => []).add(n);
    }

    final groupKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        return a.compareTo(b);
      });

    final showHeaders = groupKeys.length > 1 || groupKeys.first != null;

    final flatItems = <_NoteListItem>[];
    for (final cat in groupKeys) {
      if (showHeaders) {
        flatItems.add(_NoteHeaderItem(category: cat));
      }
      for (final n in groups[cat]!) {
        flatItems.add(_NoteDataItem(note: n));
      }
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];

        if (item is _NoteHeaderItem) {
          return _NoteCategoryHeader(
            key: ValueKey('header_${item.category}'),
            label: item.category ?? 'Geen categorie',
          );
        }

        final noteItem = item as _NoteDataItem;
        return Row(
          key: ValueKey(noteItem.note.id),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _NoteTile(
                note: noteItem.note,
                repo: widget.repo,
                showSharedBadge: widget.showSharedBadge,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        );
      },
      onReorder: (oldIndex, newIndex) {
        _onReorder(flatItems, oldIndex, newIndex);
      },
    );
  }

  void _onReorder(List<_NoteListItem> items, int oldIndex, int newIndex) {
    if (items[oldIndex] is _NoteHeaderItem) return;
    if (oldIndex < newIndex) newIndex -= 1;

    final reordered = [...items]
      ..removeAt(oldIndex)
      ..insert(newIndex, items[oldIndex]);

    final updates = <({String id, String? category, int sortOrder})>[];
    String? currentCat;
    int posInCat = 0;

    for (final item in reordered) {
      if (item is _NoteHeaderItem) {
        currentCat = item.category;
        posInCat = 0;
      } else {
        final noteItem = item as _NoteDataItem;
        updates.add((
          id: noteItem.note.id,
          category: currentCat,
          sortOrder: posInCat,
        ));
        posInCat++;
      }
    }

    widget.repo.batchUpdateCategoryAndOrder(updates);
  }
}

class _NoteCategoryHeader extends StatelessWidget {
  final String label;

  const _NoteCategoryHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
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
        ? '${note.body.substring(0, 100)}\u2026'
        : note.body;
    final reminderPassed = note.remindAt != null && isOverdue(note.remindAt!);
    final reminderColor = reminderPassed ? Colors.redAccent : kColorGold;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(note.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (preview.isNotEmpty)
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (note.remindAt != null ||
                (note.isShared && showSharedBadge)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (note.remindAt != null) ...[
                    Icon(Icons.alarm, size: 14, color: reminderColor),
                    const SizedBox(width: 4),
                    Text(
                      formatDueDate(note.remindAt!),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: reminderColor),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (note.isShared && showSharedBadge) ...[
                    Icon(Icons.lock, size: 14, color: kColorTeal),
                    const SizedBox(width: 4),
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
        onLongPress: () => _pickCategory(context),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final categories = await repo.watchNoteCategories().first;
    if (!context.mounted) return;
    final result = await showCategoryPicker(
      context: context,
      existingCategories: categories,
      currentCategory: note.category,
    );
    if (result != null) {
      await repo.updateNoteCategory(note.id, result.isEmpty ? null : result);
    }
  }
}
