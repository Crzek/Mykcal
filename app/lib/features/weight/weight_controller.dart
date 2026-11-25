import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../diary/diary_day_controller.dart';
import '../diary/local_day.dart';

/// Desfase de la zona del móvil para el «hoy» local (research R2).
int weightUtcOffsetMin(DateTime now) =>
    LocalDay.utcOffsetMin(LocalDay.today(now));

/// Gráfica de un periodo (`p30`, `p90` o `all`). Se invalida al cambiar los registros.
final weightChartProvider = FutureProvider.autoDispose
    .family<WeightChart, String>((ref, period) {
      final now = ref.watch(diaryNowProvider)();
      return ref
          .watch(mykcalApiProvider)
          .weightChart(period, weightUtcOffsetMin(now));
    });

/// Registros de peso del usuario, del más reciente al más antiguo (US1).
///
/// Si una llamada falla, el error se relanza y el estado conserva la lista anterior; el formulario
/// no limpia lo escrito (research R9).
final weightControllerProvider =
    AsyncNotifierProvider.autoDispose<WeightController, List<WeightEntry>>(
      WeightController.new,
    );

class WeightController extends AutoDisposeAsyncNotifier<List<WeightEntry>> {
  @override
  Future<List<WeightEntry>> build() =>
      ref.watch(mykcalApiProvider).weightEntries();

  int get _offset => weightUtcOffsetMin(ref.read(diaryNowProvider)());

  Future<void> save(DateTime day, double kg) async {
    await ref.read(mykcalApiProvider).saveWeight(day, kg, _offset);
    await _refresh();
  }

  Future<void> edit(DateTime day, double kg) async {
    await ref.read(mykcalApiProvider).updateWeight(day, kg, _offset);
    await _refresh();
  }

  Future<void> delete(DateTime day) async {
    await ref.read(mykcalApiProvider).deleteWeight(day, _offset);
    await _refresh();
  }

  Future<void> _refresh() async {
    final entries = await ref.read(mykcalApiProvider).weightEntries();
    state = AsyncData(entries);
    ref.invalidate(weightChartProvider);
  }
}
