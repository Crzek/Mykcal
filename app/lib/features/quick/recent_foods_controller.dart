import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Los 30 últimos alimentos distintos del usuario, por último uso (FR-001).
///
/// `DiaryDayController.apply` lo invalida: crear, editar, borrar, restaurar, copiar o deshacer
/// refrescan la lista (research R12).
final recentFoodsProvider =
    AsyncNotifierProvider.autoDispose<RecentFoodsController, List<QuickFood>>(
      RecentFoodsController.new,
    );

class RecentFoodsController extends AutoDisposeAsyncNotifier<List<QuickFood>> {
  @override
  Future<List<QuickFood>> build() => ref.watch(mykcalApiProvider).recentFoods();

  Future<void> refresh() async {
    state = const AsyncLoading<List<QuickFood>>().copyWithPrevious(state);
    state = await AsyncValue.guard(ref.read(mykcalApiProvider).recentFoods);
  }
}
