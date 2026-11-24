import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'gtin.dart';

/// Pide un código a mano. Devuelve el código normalizado o `null` si se cancela.
/// El dígito de control se comprueba antes de llamar al servidor (research R9).
Future<String?> showBarcodeManualDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const BarcodeManualDialog(),
    );

class BarcodeManualDialog extends StatefulWidget {
  const BarcodeManualDialog({super.key});

  @override
  State<BarcodeManualDialog> createState() => _BarcodeManualDialogState();
}

class _BarcodeManualDialogState extends State<BarcodeManualDialog> {
  final _text = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _text.text.trim();
    if (!isValidGtin(code)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(normalizeGtin(code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scanManual),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 14,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        decoration: InputDecoration(
          labelText: l10n.scanManualLabel,
          errorText: _invalid ? l10n.scanManualInvalid : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.scanManualSearch)),
      ],
    );
  }
}
