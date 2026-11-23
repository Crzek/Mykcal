import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';

/// Diálogo de confirmación de la baja (pantalla 7 de contracts/ui-flows.md).
///
/// Lo usan Ajustes y la pantalla de consentimiento. Si la baja va bien, cierra las pantallas
/// apiladas para que el acceso quede a la vista.
Future<void> confirmDeactivation(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final auth = ref.read(authControllerProvider.notifier);
  final errorColor = Theme.of(context).colorScheme.error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deactivateTitle),
      content: Text(l10n.deactivateBody),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: errorColor),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deactivateAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await auth.deactivate();
    navigator.popUntil((route) => route.isFirst);
  } on ApiFailure {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errDeactivate)));
  }
}
