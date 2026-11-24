import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Espera tras la última tecla antes de buscar (ui-flows, pantalla 1).
const searchDebounce = Duration(milliseconds: 300);

/// Mínimo de caracteres para lanzar una búsqueda (FR-004).
const minQueryLength = 2;

enum FoodSearchStatus {
  idle,
  tooShort,
  loading,
  results,
  empty,
  offline,
  error,
}

class FoodSearchState {
  const FoodSearchState({
    this.query = '',
    this.status = FoodSearchStatus.idle,
    this.items = const [],
  });

  /// Lo escrito por la persona; se conserva aunque falle la red.
  final String query;
  final FoodSearchStatus status;
  final List<FoodSummary> items;

  List<FoodSummary> ofKind(FoodKind kind) =>
      items.where((f) => f.kind == kind).toList(growable: false);
}

final foodSearchControllerProvider =
    NotifierProvider.autoDispose<FoodSearchController, FoodSearchState>(
      FoodSearchController.new,
    );

class FoodSearchController extends AutoDisposeNotifier<FoodSearchState> {
  Timer? _timer;
  int _generation = 0;

  @override
  FoodSearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const FoodSearchState();
  }

  /// Llamado con cada cambio del campo de texto.
  void onChanged(String text) {
    _timer?.cancel();
    final q = text.trim();
    // Invalida cualquier respuesta que siga en vuelo.
    _generation++;
    if (q.isEmpty) {
      state = FoodSearchState(query: text);
      return;
    }
    if (q.length < minQueryLength) {
      state = FoodSearchState(query: text, status: FoodSearchStatus.tooShort);
      return;
    }
    state = FoodSearchState(
      query: text,
      status: FoodSearchStatus.loading,
      items: state.items,
    );
    _timer = Timer(searchDebounce, () => _run(text));
  }

  /// «Reintentar» tras un error: repite la búsqueda sin esperar.
  void retry() {
    final text = state.query;
    if (text.trim().length < minQueryLength) return;
    _timer?.cancel();
    _generation++;
    state = FoodSearchState(
      query: text,
      status: FoodSearchStatus.loading,
      items: state.items,
    );
    _run(text);
  }

  Future<void> _run(String text) async {
    final mine = ++_generation;
    try {
      final items = await ref.read(mykcalApiProvider).searchFoods(text.trim());
      if (mine != _generation) return; // respuesta de una consulta antigua
      state = FoodSearchState(
        query: text,
        status: items.isEmpty
            ? FoodSearchStatus.empty
            : FoodSearchStatus.results,
        items: items,
      );
    } on NetworkFailure {
      if (mine != _generation) return;
      state = FoodSearchState(query: text, status: FoodSearchStatus.offline);
    } catch (_) {
      if (mine != _generation) return;
      state = FoodSearchState(query: text, status: FoodSearchStatus.error);
    }
  }
}
