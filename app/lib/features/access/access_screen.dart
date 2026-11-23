import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';

/// Pantalla de acceso (contracts/ui-flows.md).
class AccessScreen extends ConsumerWidget {
  const AccessScreen({super.key, this.notice, this.busy = false});

  final AccessNotice? notice;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(authControllerProvider.notifier);
    final message = switch (notice) {
      AccessNotice.signInFailed => l10n.signInFailed,
      AccessNotice.unavailable => l10n.signInUnavailable,
      AccessNotice.sessionExpired => l10n.sessionExpired,
      AccessNotice.accountDeactivated => l10n.deactivatedNotice,
      null => null,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.accessTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (message != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (busy)
                    Semantics(
                      label: l10n.signingIn,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    FilledButton(
                      onPressed: () => controller.signIn(),
                      child: Text(l10n.signIn),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => controller.signIn(register: true),
                      child: Text(l10n.createAccount),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
