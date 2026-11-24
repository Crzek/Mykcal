import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diary_day_controller.dart';
import 'local_day.dart';

/// Día que se está viendo en el diario (research R13).
///
/// Se mueve entre el día del alta y hoy; no hay días futuros (FR-010). Si estaba en «hoy» y la
/// fecha local cambia mientras la app dormía, pasa al día nuevo; si estaba en un día pasado, se
/// queda.
final selectedDateProvider =
    StateNotifierProvider.autoDispose<SelectedDate, DateTime>(
      (ref) => SelectedDate(ref.watch(diaryNowProvider)),
    );

class SelectedDate extends StateNotifier<DateTime> {
  SelectedDate(this._now) : super(LocalDay.today(_now())) {
    _lastToday = state;
  }

  final DateTime Function() _now;
  late DateTime _lastToday;

  DateTime get today => LocalDay.today(_now());
  bool get isToday => LocalDay.sameDay(state, today);

  /// Lleva a [day], limitado a `[first, hoy]`.
  void goTo(DateTime day, {required DateTime first}) {
    final target = LocalDay.dateOnly(day);
    if (LocalDay.isBefore(target, first)) {
      state = first;
    } else if (LocalDay.isAfter(target, today)) {
      state = today;
    } else {
      state = target;
    }
  }

  void previous({required DateTime first}) =>
      goTo(LocalDay.addDays(state, -1), first: first);

  void next({required DateTime first}) =>
      goTo(LocalDay.addDays(state, 1), first: first);

  void toToday() => state = today;

  /// La app vuelve a primer plano: la medianoche puede haber pasado.
  void resumed() {
    final now = today;
    if (LocalDay.sameDay(state, _lastToday) &&
        !LocalDay.sameDay(_lastToday, now)) {
      state = now;
    }
    _lastToday = now;
  }
}
