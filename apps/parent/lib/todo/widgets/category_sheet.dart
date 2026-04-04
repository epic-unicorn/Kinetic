import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Category picker bottom sheet
//
// Shows existing categories with a radio-selection and offers adding a new one.
//
// Returns:
//   null       → dismissed (no change)
//   ''         → user chose "Geen categorie" (clear / uncategorised)
//   non-empty  → selected or newly-created category label
// ---------------------------------------------------------------------------

Future<String?> showCategoryPicker({
  required BuildContext context,
  required List<String> existingCategories,
  String? currentCategory,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryPickerSheet(
      existingCategories: existingCategories,
      currentCategory: currentCategory,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<String> existingCategories;
  final String? currentCategory;

  const _CategoryPickerSheet({
    required this.existingCategories,
    this.currentCategory,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _newCategoryCtrl = TextEditingController();
  bool _showNewField = false;

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  void _submit(String? category) => Navigator.of(context).pop(category);

  void _addNew() {
    final label = _newCategoryCtrl.text.trim();
    if (label.isEmpty) return;
    _submit(label);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Categorie', style: tt.titleMedium),
          ),
          const SizedBox(height: 4),

          // ── "Geen categorie" ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.label_off_outlined),
            title: const Text('Geen categorie'),
            trailing: widget.currentCategory == null
                ? Icon(Icons.check, color: kColorTeal)
                : null,
            onTap: () => _submit(''),
          ),

          // ── Existing categories ─────────────────────────────────────────────
          for (final cat in widget.existingCategories)
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(cat),
              trailing: widget.currentCategory == cat
                  ? Icon(Icons.check, color: kColorTeal)
                  : null,
              onTap: () => _submit(cat),
            ),

          const Divider(height: 8),

          // ── New category ────────────────────────────────────────────────────
          if (_showNewField)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Nieuwe categorie',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addNew(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check),
                    color: kColorTeal,
                    onPressed: _addNew,
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nieuwe categorie…'),
              onTap: () => setState(() => _showNewField = true),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
