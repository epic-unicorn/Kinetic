import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../todo/services/todo_repository.dart';
import '../../todo/widgets/task_detail_sheet.dart';

// ---------------------------------------------------------------------------
// QuickAddBar — persistent text field at the bottom of the task list.
//
// Typing and pressing Enter (or tapping ✓) creates a task in the current
// list with auto-category detection.  Tapping the expand icon opens the
// full TaskDetailSheet for more options.
// ---------------------------------------------------------------------------

class QuickAddBar extends StatefulWidget {
  final TodoRepository repo;
  final String? activeListId;

  const QuickAddBar({super.key, required this.repo, this.activeListId});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    await widget.repo.createTask(title: title, listId: widget.activeListId);
    _ctrl.clear();
  }

  void _openFull() {
    final title = _ctrl.text.trim();
    _ctrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskDetailSheet(
        repo: widget.repo,
        initialListId: widget.activeListId,
        initialTitle: title.isEmpty ? null : title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(40),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Circle add button
            GestureDetector(
              onTap: _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasText
                        ? kColorTeal
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                  ),
                  color: _hasText ? kColorTeal : Colors.transparent,
                ),
                child: _hasText
                    ? const Icon(Icons.add, size: 18, color: Colors.white)
                    : Icon(
                        Icons.add,
                        size: 18,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Text field
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Nieuwe taak…',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
              ),
            ),

            // Expand to full detail
            IconButton(
              icon: Icon(
                Icons.expand_less,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Meer opties',
              onPressed: _openFull,
            ),
          ],
        ),
      ),
    );
  }
}
