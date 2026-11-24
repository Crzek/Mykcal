import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../diary/diary_day_controller.dart';
import '../diary/local_day.dart';
import '../diary/meal_labels.dart';
import '../diary/undo_snack.dart';
import 'favorites_controller.dart';
import 'quick_food_tile.dart';
import 'recent_foods_controller.dart';

/// Recientes y Favoritos de la pantalla de añadir (FR-001–FR-004, `contracts/ui-flows.md` §1).
///
/// Se ven mientras el campo de búsqueda está vacío. [tabIndex] guarda la pestaña elegida: al
/// escribir se quitan y, al borrar, vuelven en la misma. [onOpen] abre la hoja de cantidad con la
/// cantidad sugerida.
class QuickTabs extends ConsumerStatefulWidget {
  const QuickTabs({
    super.key,
    required this.date,
    required this.meal,
    required this.tabIndex,
    required this.onOpen,
  });

  final DateTime date;
  final Meal meal;
  final ValueNotifier<int> tabIndex;
  final void Function(QuickFood item) onOpen;

  @override
  ConsumerState<QuickTabs> createState() => _QuickTabsState();
}

class _QuickTabsState extends ConsumerState<QuickTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.tabIndex.value,
  )..addListener(_onTab);

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    widget.tabIndex.value = _tabs.index;
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  int get _offset => LocalDay.utcOffsetMin(widget.date);

  /// «+»: añade con la cantidad sugerida y ofrece «Deshacer» durante 5 s (FR-007).
  Future<void> _quickAdd(QuickFood item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final date = widget.date;
    final offset = _offset;
    final mealLabel = mealName(widget.meal, l10n);
    final servings = item.suggestedServings;
    try {
      final added = await ref
          .read(mykcalApiProvider)
          .addEntry(
            date: date,
            meal: widget.meal,
            foodId: item.food.id,
            quantity: servings == null ? item.suggestedQuantity : null,
            servings: servings,
            utcOffsetMin: offset,
          );
      container
          .read(diaryDayControllerProvider(date).notifier)
          .apply(added.day);
      showUndoSnack(
        messenger,
        message: l10n.quickAdded(item.food.name, mealLabel),
        undoLabel: l10n.entryUndo,
        onUndo: () async {
          try {
            final day = await container
                .read(mykcalApiProvider)
                .deleteEntry(added.entryId, offset);
            container
                .read(diaryDayControllerProvider(date).notifier)
                .apply(day);
            messenger.showSnackBar(SnackBar(content: Text(l10n.quickUndone)));
          } on ApiFailure {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.quickUndoFailed)),
            );
          }
        },
      );
    } on NetworkFailure {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.foodsOffline),
          action: SnackBarAction(
            label: l10n.retry,
            onPressed: () => _quickAdd(item),
          ),
        ),
      );
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errServer)));
    }
  }

  /// Quitar un favorito desde su pestaña ofrece «Deshacer» (vuelve a marcarlo).
  void _favoriteChanged(String foodId, bool isFavorite) {
    if (isFavorite || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context);
    showUndoSnack(
      ScaffoldMessenger.of(context),
      message: l10n.favoriteRemoved,
      undoLabel: l10n.entryUndo,
      onUndo: () =>
          container.read(favoritesControllerProvider.notifier).toggle(foodId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.quickTabRecent),
            Tab(text: l10n.quickTabFavorites),
          ],
        ),
        Expanded(
          child: _tabs.index == 0
              ? _list(
                  ref.watch(recentFoodsProvider),
                  empty: l10n.quickEmptyRecent,
                  onRetry: () => ref.invalidate(recentFoodsProvider),
                  onFavoriteChanged: null,
                )
              : _list(
                  ref
                      .watch(favoritesControllerProvider)
                      .whenData((s) => s.items),
                  empty: l10n.quickEmptyFavorites,
                  onRetry: () => ref.invalidate(favoritesControllerProvider),
                  onFavoriteChanged: _favoriteChanged,
                ),
        ),
      ],
    );
  }

  Widget _list(
    AsyncValue<List<QuickFood>> async, {
    required String empty,
    required VoidCallback onRetry,
    required void Function(String foodId, bool isFavorite)? onFavoriteChanged,
  }) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ConnectionErrorView(
        offline: error is NetworkFailure,
        onRetry: onRetry,
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(empty, textAlign: TextAlign.center),
            ),
          );
        }
        return ListView(
          children: [
            for (final item in items)
              QuickFoodTile(
                key: ValueKey(item.food.id),
                item: item,
                onAdd: _quickAdd,
                onOpen: widget.onOpen,
                onFavoriteChanged: onFavoriteChanged == null
                    ? null
                    : (isFavorite) =>
                          onFavoriteChanged(item.food.id, isFavorite),
              ),
          ],
        );
      },
    );
  }
}
