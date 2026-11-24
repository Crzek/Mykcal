import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'invitations_controller.dart';

/// Gestión del código de invitación (solo administrador).
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(invitationsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invitationsTitle)),
      body: SafeArea(
        child: status.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ConnectionErrorView(
            offline: error is NetworkFailure,
            onRetry: () => ref.invalidate(invitationsControllerProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.invitationCurrentCode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (data.displayCode == null)
                Text(l10n.invitationNoCode)
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.displayCode!,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              letterSpacing: 2,
                              fontFeatures: const [],
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.invitationCopy,
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: data.displayCode!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.invitationCopied)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                l10n.invitationSeats(
                  data.activeAccounts,
                  data.maxAccounts,
                  data.freeSeats,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () =>
                    _confirmRotate(context, ref, hasCode: data.code != null),
                child: Text(
                  data.code == null
                      ? l10n.invitationGenerate
                      : l10n.invitationChange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRotate(
    BuildContext context,
    WidgetRef ref, {
    required bool hasCode,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (!hasCode) {
      await ref.read(invitationsControllerProvider.notifier).rotate();
      return;
    }
    // Diálogo de la app, no del sistema.
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.invitationConfirmTitle),
        content: Text(l10n.invitationConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirmChange),
          ),
        ],
      ),
    );
    if (ok == true)
      await ref.read(invitationsControllerProvider.notifier).rotate();
  }
}
