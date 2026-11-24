import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'custom_food_form_screen.dart';
import 'nutrient_format.dart';

final foodDetailProvider = FutureProvider.autoDispose.family<Food, String>(
  (ref, id) => ref.watch(mykcalApiProvider).food(id),
);

/// Detalle de un alimento (pantalla 2 de contracts/ui-flows.md).
///
/// Si ya se tiene el alimento (por ejemplo, tras escanear) se pasa en `food` y no se vuelve a
/// pedir. `stale` avisa de que viene de una copia de más de 30 días. El lápiz solo se muestra si
/// el alimento es del usuario y abre el formulario en edición, salvo que se pase `onEdit`.
class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({
    super.key,
    this.foodId,
    this.food,
    this.stale = false,
    this.onEdit,
  }) : assert(foodId != null || food != null);

  final String? foodId;
  final Food? food;
  final bool stale;
  final void Function(Food food)? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loaded = food;
    if (loaded != null) return _scaffold(context, l10n, loaded);
    final async = ref.watch(foodDetailProvider(foodId!));
    return async.when(
      data: (f) => _scaffold(context, l10n, f),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.foodDetailTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.foodDetailTitle)),
        body: ConnectionErrorView(
          offline: e is NetworkFailure,
          onRetry: () => ref.invalidate(foodDetailProvider(foodId!)),
        ),
      ),
    );
  }

  /// Sustituye esta pantalla por el formulario: al guardar se vuelve al detalle ya actualizado.
  void _edit(BuildContext context, Food f) => Navigator.of(context)
      .pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CustomFoodFormScreen(existing: f),
        ),
      );

  Widget _scaffold(BuildContext context, AppLocalizations l10n, Food f) {
    final macros = macroRows(f.per100, l10n);
    final micros = microRows(f.per100, l10n);
    final missing = f.per100.hasMissing;
    final theme = Theme.of(context);
    final source = switch (f.kind) {
      FoodKind.generic => l10n.foodSourceGeneric,
      FoodKind.packaged => l10n.foodSourcePackaged,
      FoodKind.custom => l10n.foodSourceCustom,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(f.name),
        actions: [
          if (f.isMine)
            IconButton(
              tooltip: l10n.foodEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onEdit != null ? onEdit!(f) : _edit(context, f),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(source, style: theme.textTheme.titleMedium),
            if (f.brand != null) Text(l10n.foodBrand(f.brand!)),
            if (f.barcode != null) Text(l10n.foodBarcode(f.barcode!)),
            if (f.servingSize != null)
              Text(
                l10n.foodServing(
                  '${formatDecimal(f.servingSize!)} ${f.baseUnit}',
                ),
              ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                perBaseLabel(f.baseUnit, l10n),
                style: theme.textTheme.titleLarge,
              ),
            ),
            for (final r in macros) _row(context, l10n, r),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.foodMicrosTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final r in micros) _row(context, l10n, r),
            if (missing) ...[
              const SizedBox(height: 16),
              _notice(context, Icons.info_outline, l10n.foodMissingNotice),
            ],
            if (stale) ...[
              const SizedBox(height: 8),
              _notice(context, Icons.info_outline, l10n.foodStaleNotice),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, NutrientRow r) {
    return Semantics(
      label: r.semantics(l10n),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(r.label)),
            const SizedBox(width: 12),
            Text(r.text(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, semanticLabel: ''),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}
