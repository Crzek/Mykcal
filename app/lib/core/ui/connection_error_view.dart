import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Aviso de conexión con botón «Reintentar» (FR-015).
class ConnectionErrorView extends StatelessWidget {
  const ConnectionErrorView({super.key, required this.offline, required this.onRetry});

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(offline ? Icons.wifi_off : Icons.cloud_off, size: 48, semanticLabel: ''),
            const SizedBox(height: 16),
            Text(
              offline ? l10n.offlineBanner : l10n.errServer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
