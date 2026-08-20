import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 24-hour time dialog that focuses and selects the hour field so the user
/// can type immediately.
Future<TimeOfDay?> showHourFirstTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => _HourFirstTimePickerDialog(initialTime: initialTime),
  );
}

class _HourFirstTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _HourFirstTimePickerDialog({required this.initialTime});

  @override
  State<_HourFirstTimePickerDialog> createState() =>
      _HourFirstTimePickerDialogState();
}

class _HourFirstTimePickerDialogState
    extends State<_HourFirstTimePickerDialog> {
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  late final FocusNode _hourFocus;
  late final FocusNode _minuteFocus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hourCtrl = TextEditingController(
      text: widget.initialTime.hour.toString().padLeft(2, '0'),
    );
    _minuteCtrl = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
    _hourFocus = FocusNode();
    _minuteFocus = FocusNode();
    _hourFocus.addListener(_selectAllOnHourFocus);
    _minuteFocus.addListener(_selectAllOnMinuteFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hourFocus.requestFocus();
    });
  }

  void _selectAllOnHourFocus() {
    if (_hourFocus.hasFocus) {
      _hourCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _hourCtrl.text.length,
      );
    }
  }

  void _selectAllOnMinuteFocus() {
    if (_minuteFocus.hasFocus) {
      _minuteCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _minuteCtrl.text.length,
      );
    }
  }

  @override
  void dispose() {
    _hourFocus.removeListener(_selectAllOnHourFocus);
    _minuteFocus.removeListener(_selectAllOnMinuteFocus);
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _onHourChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    if (digits.length == 1) {
      final d = int.parse(digits);
      // 3–9 can only mean 03–09; jump to minutes so typing 930 → 09:30.
      if (d > 2) {
        _hourCtrl.value = TextEditingValue(
          text: d.toString().padLeft(2, '0'),
          selection: const TextSelection.collapsed(offset: 2),
        );
        _minuteFocus.requestFocus();
      }
      return;
    }

    var hour = int.parse(digits.substring(0, 2));
    if (hour > 23) hour = 23;
    _hourCtrl.value = TextEditingValue(
      text: hour.toString().padLeft(2, '0'),
      selection: const TextSelection.collapsed(offset: 2),
    );
    _minuteFocus.requestFocus();
  }

  void _onMinuteChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    if (digits.length == 1) {
      final d = int.parse(digits);
      if (d > 5) {
        _minuteCtrl.value = TextEditingValue(
          text: d.toString().padLeft(2, '0'),
          selection: const TextSelection.collapsed(offset: 2),
        );
      }
      return;
    }

    var minute = int.parse(digits.substring(0, 2));
    if (minute > 59) minute = 59;
    _minuteCtrl.value = TextEditingValue(
      text: minute.toString().padLeft(2, '0'),
      selection: const TextSelection.collapsed(offset: 2),
    );
  }

  void _submit() {
    final hour = int.tryParse(_hourCtrl.text);
    final minute = int.tryParse(_minuteCtrl.text);
    if (hour == null ||
        hour < 0 ||
        hour > 23 ||
        minute == null ||
        minute < 0 ||
        minute > 59) {
      setState(() => _error = 'Voer een geldige tijd in (00:00 – 23:59).');
      return;
    }
    Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Tijd'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeDigitField(
                fieldKey: const ValueKey('hour-field'),
                controller: _hourCtrl,
                focusNode: _hourFocus,
                onChanged: _onHourChanged,
                onSubmitted: (_) => _minuteFocus.requestFocus(),
                textInputAction: TextInputAction.next,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: tt.headlineMedium?.copyWith(color: scheme.onSurface),
                ),
              ),
              _TimeDigitField(
                fieldKey: const ValueKey('minute-field'),
                controller: _minuteCtrl,
                focusNode: _minuteFocus,
                onChanged: _onMinuteChanged,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: tt.bodySmall?.copyWith(color: scheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

class _TimeDigitField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final TextInputAction textInputAction;

  const _TimeDigitField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        style: Theme.of(context).textTheme.headlineMedium,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
