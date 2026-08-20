import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class MnemonicPhraseField extends StatelessWidget {
  const MnemonicPhraseField({
    super.key,
    required this.controller,
    this.errorText,
  });

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: l10n.vaultPhraseFieldLabel,
        alignLabelWithHint: true,
        errorText: errorText,
      ),
    );
  }
}
