import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/format/numbers.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'target_controller.dart';
import 'target_screen.dart';

/// Tarjeta «Tu objetivo de hoy» del inicio (pantalla 5 de contracts/ui-flows.md).
class TargetCard extends ConsumerWidget {
  const TargetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ref
        .watch(targetProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ConnectionErrorView(
            offline: error is NetworkFailure,
            onRetry: () => ref.invalidate(targetProvider),
          ),
          data: (target) {
            final v = target.values;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.homeTargetTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatInt(v.kcal)} kcal',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.nutrientProtein}: ${formatInt(v.proteinG)} g\n'
                      '${l10n.nutrientCarbs}: ${formatInt(v.carbsG)} g\n'
                      '${l10n.nutrientFat}: ${formatInt(v.fatG)} g',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TargetScreen(),
                        ),
                      ),
                      child: Text(l10n.homeTargetDetail),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}
