import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format/numbers.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'target_controller.dart';
import 'target_edit_screen.dart';

/// Objetivo diario (pantalla 3 de contracts/ui-flows.md).
///
/// Con [result] es el resultado del onboarding («Empezar»); sin él es el detalle, que lee el
/// objetivo vigente y permite editarlo.
class TargetScreen extends ConsumerWidget {
  const TargetScreen({super.key, this.result});

  final DailyTarget? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fixed = result;
    final Widget body;
    if (fixed != null) {
      body = _TargetBody(target: fixed, resultMode: true);
    } else {
      body = ref
          .watch(targetProvider)
          .when(
            data: (target) => _TargetBody(target: target, resultMode: false),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ConnectionErrorView(
              offline: error is NetworkFailure,
              onRetry: () => ref.invalidate(targetProvider),
            ),
          );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.targetTitle),
        automaticallyImplyLeading: fixed == null,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _TargetBody extends ConsumerWidget {
  const _TargetBody({required this.target, required this.resultMode});

  final DailyTarget target;
  final bool resultMode;

  Future<void> _backToCalculation(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.backToCalcTitle),
        content: Text(l10n.backToCalcBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.targetBackToCalc),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(mykcalApiProvider).recalculateTarget();
      ref.invalidate(targetProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.targetRecalculated)));
    } on NetworkFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errOffline)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = target.values;
    final minKcal = target.calculation.sex == 'male' ? 1500 : 1200;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (target.manual)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.edit_note, semanticLabel: ''),
                const SizedBox(width: 8),
                Text(
                  l10n.targetEditedBadge,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        MergeSemantics(
          child: Text(
            '${formatInt(v.kcal)} kcal',
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 16),
        _row(context, l10n.nutrientProtein, v.proteinG, 'g'),
        _row(context, l10n.nutrientCarbs, v.carbsG, 'g'),
        _row(context, l10n.nutrientFat, v.fatG, 'g'),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            l10n.targetMicrosTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        _row(context, l10n.nutrientFiber, v.fiberG, 'g', kind: l10n.kindMin),
        _row(
          context,
          l10n.nutrientSodium,
          v.sodiumMg,
          'mg',
          kind: l10n.kindMax,
        ),
        _row(
          context,
          l10n.nutrientPotassium,
          v.potassiumMg,
          'mg',
          kind: l10n.kindMin,
        ),
        _row(
          context,
          l10n.nutrientCalcium,
          v.calciumMg,
          'mg',
          kind: l10n.kindMin,
        ),
        _row(context, l10n.nutrientIron, v.ironMg, 'mg', kind: l10n.kindMin),
        _row(
          context,
          l10n.nutrientMagnesium,
          v.magnesiumMg,
          'mg',
          kind: l10n.kindMin,
        ),
        _row(
          context,
          l10n.nutrientVitD,
          v.vitaminDUg,
          'µg',
          kind: l10n.kindMin,
        ),
        _row(
          context,
          l10n.nutrientVitC,
          v.vitaminCMg,
          'mg',
          kind: l10n.kindMin,
        ),
        if (target.calculation.notices.contains('MIN_KCAL_APPLIED'))
          _notice(context, l10n.noticeMinKcal(formatInt(minKcal))),
        if (target.calculation.notices.contains('CARBS_CLAMPED'))
          _notice(context, l10n.noticeCarbsClamped),
        const SizedBox(height: 24),
        if (resultMode)
          FilledButton(
            onPressed: () {
              final auth = ref.read(authControllerProvider.notifier);
              Navigator.of(context).popUntil((route) => route.isFirst);
              auth.refreshAccount();
            },
            child: Text(l10n.targetStart),
          )
        else ...[
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TargetEditScreen(initial: v),
              ),
            ),
            child: Text(l10n.targetEdit),
          ),
          if (target.manual) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _backToCalculation(context, ref),
              child: Text(l10n.targetBackToCalc),
            ),
          ],
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int value,
    String unit, {
    String? kind,
  }) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text('${formatInt(value)} $unit', style: style),
            if (kind != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(kind, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color: Theme.of(context).colorScheme.error,
            semanticLabel: '',
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
