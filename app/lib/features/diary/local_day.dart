export '../../core/format/dates.dart' show isoDate;

/// Zona horaria del `DateTime` local: desfase en minutos del instante dado respecto a UTC.
typedef OffsetOf = int Function(DateTime localInstant);

int _systemOffset(DateTime localInstant) =>
    localInstant.timeZoneOffset.inMinutes;

/// Fechas locales del diario (research R1, R3). Todo son fechas del móvil, sin hora.
abstract final class LocalDay {
  /// Día local de [now] sin hora.
  static DateTime today(DateTime now) => dateOnly(now);

  /// Quita la hora de un `DateTime`.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Desfase en minutos de la zona del móvil **al final de ese día**: el que tiene su medianoche
  /// local siguiente. Con el horario de verano, el cambio de hora cae dentro del día y el
  /// servidor necesita el desfase que rige al cerrarlo.
  static int utcOffsetMin(DateTime day, {OffsetOf offsetOf = _systemOffset}) =>
      offsetOf(DateTime(day.year, day.month, day.day + 1));

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `a` es un día anterior a `b` (compara solo la fecha).
  static bool isBefore(DateTime a, DateTime b) =>
      dateOnly(a).isBefore(dateOnly(b));

  /// `a` es un día posterior a `b` (compara solo la fecha).
  static bool isAfter(DateTime a, DateTime b) =>
      dateOnly(a).isAfter(dateOnly(b));

  /// Día siguiente o anterior; seguro con los cambios de hora.
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}
