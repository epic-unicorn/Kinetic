import 'package:flutter/material.dart';

import '../../main.dart';
import '../../settings/settings_repository.dart';
import '../../theme/app_header.dart';
import '../../theme/app_theme.dart';
import '../models/personal_note.dart';
import '../services/note_repository.dart';
import '../widgets/category_sheet.dart';
import 'note_editor_screen.dart';

/// Screen that displays all notes in a scrollable list with create/edit/delete.
class NotesScreen extends StatefulWidget {
  final NoteRepository repo;
  final SettingsRepository? settingsRepo;
  final ValueNotifier<SyncStatus>? syncStatus;
  final bool partnerPaired;
  final VoidCallback? onSyncRetry;

  const NotesScreen({
    super.key,
    required this.repo,
    this.settingsRepo,
    this.syncStatus,
    this.partnerPaired = false,
    this.onSyncRetry,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  int get _tabCount => widget.partnerPaired ? 2 : 1;

  bool get _onSharedTab => widget.partnerPaired && (_tabController?.index == 1);

  @override
  void initState() {
    super.initState();
    if (widget.partnerPaired) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partnerPaired != widget.partnerPaired) {
      _tabController?.dispose();
      _tabController = widget.partnerPaired
          ? TabController(length: 2, vsync: this)
          : null;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _openEditor({
    PersonalNote? note,
    bool initialIsShared = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<PersonalNote?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NoteEditorScreen(
        repo: widget.repo,
        note: note,
        hasFamilyKey: widget.partnerPaired,
        initialIsShared: note?.isShared ?? initialIsShared,
      ),
    );
    if (context.mounted && result != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Notitie opgeslagen')),
      );
    }
  }

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
                SyncStatus.error => IconButton(
                  onPressed: widget.onSyncRetry,
                  tooltip: 'Sync mislukt, tap om opnieuw te proberen.',
                  icon: Icon(
                    Icons.sync_problem_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                SyncStatus.idle => IconButton(
                  onPressed: widget.onSyncRetry,
                  tooltip: 'Synchroniseren',
                  icon: const Icon(Icons.cloud_done_outlined),
                ),
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(initialIsShared: _onSharedTab),
          ),
        ],
        bottom: widget.partnerPaired && _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Privé'),
                  Tab(text: 'Gedeeld'),
                ],
              )
            : null,
      ),
      body: widget.partnerPaired && _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _NotesTabBody(
                  repo: widget.repo,
                  settingsRepo: widget.settingsRepo,
                  isShared: false,
                  onEditNote: (note) => _openEditor(note: note),
                ),
                _NotesTabBody(
                  repo: widget.repo,
                  settingsRepo: widget.settingsRepo,
                  isShared: true,
                  onEditNote: (note) => _openEditor(note: note),
                ),
              ],
            )
          : _NotesTabBody(
              repo: widget.repo,
              settingsRepo: widget.settingsRepo,
              isShared: false,
              onEditNote: (note) => _openEditor(note: note),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(initialIsShared: _onSharedTab),
        tooltip: 'Nieuwe notitie',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-tab body: filtered note list or empty state
// ---------------------------------------------------------------------------

class _NotesTabBody extends StatelessWidget {
  final NoteRepository repo;
  final SettingsRepository? settingsRepo;
  final bool isShared;
  final void Function(PersonalNote note) onEditNote;

  const _NotesTabBody({
    required this.repo,
    this.settingsRepo,
    required this.isShared,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalNote>>(
      stream: repo.watchAll(),
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

        final notes = (snapshot.data ?? [])
            .where((n) => n.isShared == isShared)
            .toList();

        if (notes.isEmpty) {
          final scheme = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isShared ? Icons.people_outline : Icons.note_outlined,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  isShared ? 'Geen gedeelde notities' : 'Geen privé notities',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  isShared
                      ? 'Notities gedeeld met je partner verschijnen hier'
                      : 'Je privé notities verschijnen hier',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _NoteGroupedList(
          notes: notes,
          repo: repo,
          settingsRepo: settingsRepo,
          showSharedBadge: false,
          onEditNote: onEditNote,
        );
      },
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
  final SettingsRepository? settingsRepo;
  final bool showSharedBadge;
  final void Function(PersonalNote note) onEditNote;

  const _NoteGroupedList({
    required this.notes,
    required this.repo,
    this.settingsRepo,
    required this.showSharedBadge,
    required this.onEditNote,
  });

  @override
  State<_NoteGroupedList> createState() => _NoteGroupedListState();
}

class _NoteGroupedListState extends State<_NoteGroupedList> {
  List<String?> _categoryOrder = [];

  @override
  void initState() {
    super.initState();
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    if (widget.settingsRepo == null) return;
    final saved = await widget.settingsRepo!.loadNoteCategoryOrder();
    if (mounted) setState(() => _categoryOrder = saved);
  }

  void _saveCategoryOrder(List<String?> order) {
    widget.settingsRepo?.saveNoteCategoryOrder(order);
  }

  List<String?> _mergeOrder(Iterable<String?> streamKeys) {
    final known = Set<String?>.from(streamKeys);
    final merged = _categoryOrder.where(known.contains).toList();
    for (final k in streamKeys) {
      if (!merged.contains(k)) merged.add(k);
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    // Group notes by category
    final groups = <String?, List<PersonalNote>>{};
    for (final n in widget.notes) {
      groups.putIfAbsent(n.category, () => []).add(n);
    }

    // Use saved order merged with current categories
    final merged = _mergeOrder(groups.keys);
    if (merged.length != _categoryOrder.length ||
        !merged.every(_categoryOrder.contains)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categoryOrder = _mergeOrder(groups.keys));
      });
    }

    final groupKeys = merged.where(groups.containsKey).toList();

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
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];

        if (item is _NoteHeaderItem) {
          return _NoteCategoryHeader(
            key: ValueKey('header_${item.category}'),
            label: item.category ?? 'Geen categorie',
            index: index,
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
                onTap: () => widget.onEditNote(noteItem.note),
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
    if (oldIndex < newIndex) newIndex -= 1;

    if (items[oldIndex] is _NoteHeaderItem) {
      // Header drag → reorder category blocks
      final reordered = [...items]
        ..removeAt(oldIndex)
        ..insert(newIndex, items[oldIndex]);
      final newOrder = <String?>[];
      for (final item in reordered) {
        if (item is _NoteHeaderItem) newOrder.add(item.category);
      }
      setState(() => _categoryOrder = newOrder);
      _saveCategoryOrder(newOrder);
      return;
    }

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
  final int index;

  const _NoteCategoryHeader({
    super.key,
    required this.label,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 4),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  final PersonalNote note;
  final NoteRepository repo;
  final bool showSharedBadge;
  final VoidCallback onTap;

  const _NoteTile({
    required this.note,
    required this.repo,
    required this.onTap,
    this.showSharedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reminderPassed = note.remindAt != null && isOverdue(note.remindAt!);
    final reminderColor = reminderPassed ? Colors.redAccent : null;
    final metaColor = scheme.onSurfaceVariant;
    final showMeta =
        note.remindAt != null || (note.isShared && showSharedBadge);

    return InkWell(
      onTap: onTap,
      onLongPress: () => _pickCategory(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1, right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant, width: 2),
                color: scheme.surfaceContainerHighest.withAlpha(80),
              ),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title, style: tt.bodyLarge),
                  if (showMeta) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (note.remindAt != null)
                          Text(
                            formatDueDate(note.remindAt!, allDay: false),
                            style: tt.labelSmall?.copyWith(
                              color: reminderColor ?? metaColor,
                            ),
                          ),
                        if (note.remindAt != null &&
                            note.isShared &&
                            showSharedBadge)
                          Text(' · ', style: TextStyle(color: metaColor)),
                        if (note.isShared && showSharedBadge)
                          Text(
                            'Gedeeld',
                            style: tt.labelSmall?.copyWith(color: kColorTeal),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
