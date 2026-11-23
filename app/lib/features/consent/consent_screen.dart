import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../settings/deactivate_dialog.dart';

/// Consentimiento de datos de salud (pantalla 1 de contracts/ui-flows.md).
///
/// Sin aceptar no se avanza; las únicas salidas son cerrar sesión y darse de baja.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;
  bool _busy = false;

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(mykcalApiProvider).acceptConsent(l10n.consentTextVersion);
      await ref.read(authControllerProvider.notifier).refreshAccount();
    } on ApiError catch (e) {
      final text = e.code == 'CONSENT_VERSION_MISMATCH'
          ? l10n.errUpdateApp
          : l10n.errGeneric;
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } on NetworkFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errOffline)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errServer)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.read(authControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.consentTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.consentBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _accepted = v ?? false),
                title: Text(l10n.consentCheckbox),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _accepted && !_busy ? _accept : null,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.consentAccept),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => auth.signOut(),
                    child: Text(l10n.signOut),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _busy
                        ? null
                        : () => confirmDeactivation(context, ref),
                    child: Text(l10n.deactivateAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
