import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Favoritos del usuario y el conjunto de sus ids, para pintar la estrella en cualquier pantalla
/// (research R9).
class FavoritesState {
  FavoritesState(this.items) : ids = {for (final i in items) i.food.id};

  const FavoritesState._(this.items, this.ids);

  final List<QuickFood> items;
  final Set<String> ids;

  FavoritesState without(String foodId) => FavoritesState._(
    items.where((i) => i.food.id != foodId).toList(),
    {...ids}..remove(foodId),
  );

  FavoritesState withId(String foodId) =>
      FavoritesState._(items, {...ids, foodId});
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );

/// Ids de los favoritos; vacío mientras carga.
final favoriteIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(favoritesControllerProvider).valueOrNull?.ids ?? const {},
);

class FavoritesController extends AsyncNotifier<FavoritesState> {
  @override
  Future<FavoritesState> build() async =>
      FavoritesState(await ref.watch(mykcalApiProvider).favoriteFoods());

  /// Marca o desmarca [foodId] al momento; si la petición falla, devuelve el estado anterior y
  /// relanza el error para que la pantalla avise.
  Future<void> toggle(String foodId) async {
    // Con la lista ya cargada el cambio es inmediato; si no, espera a que cargue.
    final previous = state.valueOrNull ?? await future;
    final api = ref.read(mykcalApiProvider);
    final wasFavorite = previous.ids.contains(foodId);
    state = AsyncData(
      wasFavorite ? previous.without(foodId) : previous.withId(foodId),
    );
    try {
      if (wasFavorite) {
        await api.removeFavorite(foodId);
        return;
      }
      await api.addFavorite(foodId);
    } on ApiFailure {
      state = AsyncData(previous);
      rethrow;
    }
    // Al marcar, la lista completa (con cantidades sugeridas) viene del servidor.
    try {
      state = AsyncData(FavoritesState(await api.favoriteFoods()));
    } on ApiFailure {
      // La estrella ya está marcada; la lista se actualizará la próxima vez.
    }
  }
}
