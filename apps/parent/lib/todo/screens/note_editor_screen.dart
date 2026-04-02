import 'package:flutter/material.dart';

import '../models/personal_note.dart';
import '../services/note_repository.dart';

/// Screen for creating or editing a note.
class NoteEditorScreen extends StatefulWidget {
  final NoteRepository repo;
  final PersonalNote? note;
  final bool hasFamilyKey;

  const NoteEditorScreen({
    super.key,
    required this.repo,
    this.note,
    this.hasFamilyKey = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late bool _isShared;
  late DateTime? _remindAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _bodyCtrl = TextEditingController(text: note?.body ?? '');
    _isShared = note?.isShared ?? false;
    _remindAt = note?.remindAt;
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
      ).showSnackBar(const SnackBar(content: Text('Titel is verplicht')));
      return;
    }

    setState(() => _saving = true);
    try {
      final note = widget.note;
      late final PersonalNote savedNote;

      if (note != null) {
        // Update existing
        final updatedNote = note.copyWith(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text,
          isShared: _isShared,
          remindAt: _remindAt,
        );
        await widget.repo.update(updatedNote);
        savedNote = updatedNote;
      } else {
        // Create new
        savedNote = await widget.repo.insert(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text,
          isShared: _isShared,
          remindAt: _remindAt,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(savedNote);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt ?? now),
    );
    if (time == null) return;

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Notitie bewerken' : 'Nieuwe notitie'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Titel',
                prefixIcon: const Icon(Icons.note_outlined),
                hintText: 'Bijv. Boodschappenlijst',
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Body
            TextField(
              controller: _bodyCtrl,
              decoration: InputDecoration(
                labelText: 'Inhoud',
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: 'Notitie inhoud (markdown ondersteund)',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                alignLabelWithHint: true,
              ),
              minLines: 8,
              maxLines: null,
            ),
            const SizedBox(height: 20),

            // Reminder
            ListTile(
              leading: const Icon(Icons.alarm_outlined),
              title: const Text('Herinnering'),
              subtitle: Text(
                _remindAt != null
                    ? '${_remindAt!.day}/${_remindAt!.month} ${_remindAt!.hour.toString().padLeft(2, '0')}:${_remindAt!.minute.toString().padLeft(2, '0')}'
                    : 'Geen herinnering',
              ),
              trailing: _remindAt != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _remindAt = null),
                    )
                  : null,
              onTap: _pickReminder,
            ),
            const SizedBox(height: 12),

            // Is Shared toggle
            SwitchListTile(
              title: const Text('Gedeeld met partner'),
              subtitle: Text(
                widget.hasFamilyKey
                    ? 'Versleuteld met gezinssleutel'
                    : 'Koppel eerst met je partner',
              ),
              value: _isShared,
              onChanged: widget.hasFamilyKey ? (v) => setState(() => _isShared = v) : null,
              secondary: const Icon(Icons.lock_outlined),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Opslaan…' : 'Opslaan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
