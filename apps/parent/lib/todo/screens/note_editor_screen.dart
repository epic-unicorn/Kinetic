import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../theme/app_theme.dart';
import '../models/personal_note.dart';
import '../reminder_time.dart';
import '../services/note_repository.dart';
import '../widgets/category_sheet.dart';
import '../widgets/detail_meta_row.dart';
import '../widgets/hour_first_time_picker.dart';

/// Bottom sheet for creating or editing a note. Mirrors [TaskDetailSheet] layout.
class NoteEditorScreen extends StatefulWidget {
  final NoteRepository repo;
  final PersonalNote? note;
  final bool hasFamilyKey;
  final bool initialIsShared;

  const NoteEditorScreen({
    super.key,
    required this.repo,
    this.note,
    this.hasFamilyKey = false,
    this.initialIsShared = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late bool _isShared;
  late DateTime? _remindAt;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _bodyCtrl = TextEditingController(text: note?.body ?? '');
    _isShared = note?.isShared ?? widget.initialIsShared;
    _remindAt = note?.remindAt;
    _category = note?.category;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).notesTitleRequired)));
      return;
    }

    setState(() => _saving = true);
    try {
      final note = widget.note;
      late final PersonalNote savedNote;

      if (note != null) {
        final updatedNote = note.copyWith(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text,
          isShared: _isShared,
          remindAt: _remindAt,
          clearRemindAt: _remindAt == null,
          category: _category,
          clearCategory: _category == null,
        );
        await widget.repo.update(updatedNote);
        savedNote = updatedNote;
      } else {
        savedNote = await widget.repo.insert(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text,
          isShared: _isShared,
          remindAt: _remindAt,
          category: _category,
        );
      }

      if (mounted) Navigator.pop(context, savedNote);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonSaveError('$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCategory() async {
    final categories = await widget.repo.watchNoteCategories().first;
    if (!mounted) return;
    final result = await showCategoryPicker(
      context: context,
      existingCategories: categories,
      currentCategory: _category,
    );
    if (result != null && mounted) {
      setState(() => _category = result.isEmpty ? null : result);
    }
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remindAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showHourFirstTimePicker(
      context: context,
      initialTime: _remindAt != null
          ? TimeOfDay.fromDateTime(_remindAt!)
          : TimeOfDay.fromDateTime(suggestedReminderAt(DateTime.now())),
    );
    if (time == null || !mounted) return;

    setState(() {
      _remindAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).notesDeleteTitle),
        content: Text(AppLocalizations.of(context).notesDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repo.delete(widget.note!.id);
      if (mounted) Navigator.pop(context, null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonDeleteError('$e'))));
      }
    }
  }

  String _formatDateOnly(DateTime dt) {
    const months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTimeOnly(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleCtrl,
              autofocus: widget.note == null,
              style: tt.titleLarge,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).commonTitle,
                hintStyle: tt.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _bodyCtrl,
              style: tt.bodyMedium,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).commonContent,
                hintStyle: tt.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: null,
            ),
          ),
          const Divider(height: 16),
          DetailMetaRow(
            icon: Icons.alarm_outlined,
            label: AppLocalizations.of(context).commonReminder,
            active: _remindAt != null,
            onTap: _pickReminder,
            titleWidget: _remindAt != null
                ? Text(
                    '${_formatDateOnly(_remindAt!.toLocal())} · '
                    '${_formatTimeOnly(_remindAt!.toLocal())}',
                    style: tt.bodyMedium?.copyWith(color: kColorTeal),
                  )
                : null,
            trailing: _remindAt != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _remindAt = null),
                  )
                : null,
          ),
          DetailMetaRow(
            icon: Icons.label_outline,
            label: _category ?? AppLocalizations.of(context).taskAddCategory,
            active: _category != null,
            onTap: _pickCategory,
            trailing: _category != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _category = null),
                  )
                : null,
          ),
          if (widget.hasFamilyKey)
            DetailMetaRow(
              icon: Icons.people_outline,
              label: AppLocalizations.of(context).notesSharedWithPartner,
              active: _isShared,
              onTap: () => setState(() => _isShared = !_isShared),
              trailing: Switch(
                value: _isShared,
                onChanged: (v) => setState(() => _isShared = v),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                if (widget.note != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: AppLocalizations.of(context).commonDelete,
                    onPressed: _saving ? null : _confirmDelete,
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(widget.note == null ? AppLocalizations.of(context).commonAdd : AppLocalizations.of(context).commonSave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
