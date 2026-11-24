import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/format/numbers.dart';
import '../../l10n/app_localizations.dart';
import 'barcode_scan_screen.dart';
import 'custom_food_form_screen.dart';
import 'food_detail_screen.dart';
import 'my_foods_screen.dart';
import 'food_search_controller.dart';

/// Buscar alimentos (pantalla 1 de contracts/ui-flows.md).
///
/// Buscar alimentos (pantalla 1 de contracts/ui-flows.md). Desde aquí se crea un alimento con el
/// nombre escrito, se escanea un código y se abre «Mis alimentos».
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _text = TextEditingController();

  void _push(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  void _createFromBarcode(String code, String? name, String? brand) => _push(
    CustomFoodFormScreen(
      initialBarcode: code,
      initialName: name,
      initialBrand: brand,
    ),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(foodSearchControllerProvider);
    final controller = ref.read(foodSearchControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.foodsTitle),
        actions: [
          IconButton(
            tooltip: l10n.foodsScan,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BarcodeScanScreen(onCreate: _createFromBarcode),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: controller.onChanged,
                decoration: InputDecoration(
                  labelText: l10n.foodsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: s.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.foodsSearchClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _text.clear();
                            controller.onChanged('');
                          },
                        ),
                  helperText: s.status == FoodSearchStatus.tooShort
                      ? l10n.foodsMinChars
                      : null,
                ),
              ),
            ),
            if (s.status == FoodSearchStatus.loading)
              Semantics(
                liveRegion: true,
                label: l10n.foodsSearching,
                child: const LinearProgressIndicator(),
              ),
            Expanded(child: _body(context, l10n, s, controller)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => _push(const MyFoodsScreen()),
                child: Text(l10n.foodsMyFoods),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    FoodSearchState s,
    FoodSearchController controller,
  ) {
    switch (s.status) {
      case FoodSearchStatus.idle:
      case FoodSearchStatus.tooShort:
        return const SizedBox.shrink();
      case FoodSearchStatus.offline:
      case FoodSearchStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.status == FoodSearchStatus.offline
                      ? l10n.foodsOffline
                      : l10n.errServer,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.retry,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        );
      case FoodSearchStatus.empty:
        final q = s.query.trim();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.foodsNoResults(q), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _push(CustomFoodFormScreen(initialName: q)),
                  child: Text(l10n.foodsCreateNamed(q)),
                ),
              ],
            ),
          ),
        );
      case FoodSearchStatus.loading:
      case FoodSearchStatus.results:
        return ListView(
          children: [
            _section(context, l10n.foodsSectionMine, s.ofKind(FoodKind.custom)),
            _section(
              context,
              l10n.foodsSectionGeneric,
              s.ofKind(FoodKind.generic),
            ),
            _section(
              context,
              l10n.foodsSectionPackaged,
              s.ofKind(FoodKind.packaged),
            ),
          ],
        );
    }
  }

  Widget _section(BuildContext context, String title, List<FoodSummary> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        for (final f in items) _FoodTile(food: f),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food});

  final FoodSummary food;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kcal = formatDecimal(food.kcal);
    final per = food.baseUnit == 'ml'
        ? l10n.foodsRowKcalMl(kcal)
        : l10n.foodsRowKcalG(kcal);
    final label = [
      food.name,
      if (food.brand != null) food.brand!,
      per,
      if (food.isMine) l10n.foodsRowMineSemantics,
    ].join(', ');
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: ListTile(
        minTileHeight: 56,
        title: Text(food.name),
        subtitle: food.brand == null ? null : Text(food.brand!),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (food.isMine) Text(l10n.foodsMineBadge),
            Text('$kcal kcal'),
          ],
        ),
        onTap: () => _open(context),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FoodDetailScreen(foodId: food.id)),
  );
}
