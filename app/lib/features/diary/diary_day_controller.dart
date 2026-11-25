import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../quick/recent_foods_controller.dart';
import 'local_day.dart';

/// Reloj del diario: las pruebas lo sustituyen para fijar «hoy».
final diaryNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Día del diario de la última respuesta del servidor (research R9, R13).
///
/// El servidor manda: cada ruta que cambia el día devuelve el día completo y recalculado, y se
/// aplica con [apply]. La app no suma nada por su cuenta.
final diaryDayControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryDayController, DiaryDay, DateTime>(DiaryDayController.new);

class DiaryDayController
    extends AutoDisposeFamilyAsyncNotifier<DiaryDay, DateTime> {
  @override
  Future<DiaryDay> build(DateTime arg) =>
      ref.watch(mykcalApiProvider).diaryDay(arg, LocalDay.utcOffsetMin(arg));

  /// Sustituye el estado con la respuesta de una ruta del diario. Como cambia lo que se ha
  /// registrado, también refresca Recientes (005 R12).
  void apply(DiaryDay day) {
    state = AsyncData(day);
    ref.invalidate(recentFoodsProvider);
  }
}
