import 'package:flutter/material.dart';

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
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: 'Herstelzin (12 woorden)',
        alignLabelWithHint: true,
        errorText: errorText,
      ),
    );
  }
}
