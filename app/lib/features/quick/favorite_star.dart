import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../l10n/app_localizations.dart';
import 'favorites_controller.dart';

/// Marca o desmarca un alimento como favorito (FR-003). Mismo control en la búsqueda, en recientes
/// y en la hoja de una entrada. [onChanged] avisa con el nuevo estado (p. ej. para ofrecer
/// «Deshacer» al quitarlo).
class FavoriteStar extends ConsumerWidget {
  const FavoriteStar({
    super.key,
    required this.foodId,
    required this.foodName,
    this.onChanged,
  });

  final String foodId;
  final String foodName;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Ver el estado dispara la carga de favoritos la primera vez.
    ref.watch(favoritesControllerProvider);
    final isFavorite = ref.watch(favoriteIdsProvider).contains(foodId);
    final label = isFavorite
        ? l10n.favoriteUnmark(foodName)
        : l10n.favoriteMark(foodName);
    return IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: label,
      isSelected: isFavorite,
      icon: const Icon(Icons.star_border),
      selectedIcon: const Icon(Icons.star),
      onPressed: () => _toggle(context, ref, isFavorite),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool wasFavorite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(favoritesControllerProvider.notifier).toggle(foodId);
      onChanged?.call(!wasFavorite);
    } on NetworkFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.foodsOffline)));
    } on ApiError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'FOOD_NOT_FOUND'
                ? l10n.favoriteUnavailable
                : l10n.errServer,
          ),
        ),
      );
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errServer)));
    }
  }
}
